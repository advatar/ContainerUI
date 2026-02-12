import Foundation

public struct CommandResult: Sendable, Hashable {
    public let command: String
    public let arguments: [String]
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let duration: TimeInterval
}

public enum ProcessRunnerError: Error, LocalizedError, Sendable {
    case executableNotFound(String)
    case failedToStart(String)
    case commandFailed(command: String, arguments: [String], exitCode: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "Executable not found: \(name)"
        case .failedToStart(let msg):
            return "Failed to start process: \(msg)"
        case .commandFailed(let command, let arguments, let exitCode, let stderr):
            let args = arguments.joined(separator: " ")
            let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return tail.isEmpty
                ? "Command failed (\(exitCode)): \(command) \(args)"
                : "Command failed (\(exitCode)): \(command) \(args)\n\n\(tail)"
        }
    }
}

public enum OutputSource: String, Sendable, Hashable {
    case stdout
    case stderr
}

public struct OutputLine: Sendable, Hashable {
    public let source: OutputSource
    public let line: String
}

private final class StreamLineState: @unchecked Sendable {
    private let lock = NSLock()
    private let newline = Data([0x0A]) // '\n'

    private var outBuffer = Data()
    private var errBuffer = Data()
    private var stderrCollected = Data()
    private var terminatedByUser = false

    func appendStdout(_ data: Data, continuation: AsyncThrowingStream<OutputLine, Error>.Continuation) {
        let lines: [OutputLine]
        lock.lock()
        outBuffer.append(data)
        lines = drainLines(from: &outBuffer, source: .stdout, final: false)
        lock.unlock()

        for line in lines {
            continuation.yield(line)
        }
    }

    func appendStderr(_ data: Data, continuation: AsyncThrowingStream<OutputLine, Error>.Continuation) {
        let lines: [OutputLine]
        lock.lock()
        stderrCollected.append(data)
        errBuffer.append(data)
        lines = drainLines(from: &errBuffer, source: .stderr, final: false)
        lock.unlock()

        for line in lines {
            continuation.yield(line)
        }
    }

    func markTerminatedByUser() {
        lock.lock()
        terminatedByUser = true
        lock.unlock()
    }

    func flushAndSnapshot(
        continuation: AsyncThrowingStream<OutputLine, Error>.Continuation
    ) -> (terminatedByUser: Bool, collectedErr: String) {
        let stdoutLines: [OutputLine]
        let stderrLines: [OutputLine]
        let wasTerminatedByUser: Bool
        let collectedErr: String

        lock.lock()
        stdoutLines = drainLines(from: &outBuffer, source: .stdout, final: true)
        stderrLines = drainLines(from: &errBuffer, source: .stderr, final: true)
        wasTerminatedByUser = terminatedByUser
        collectedErr = String(data: stderrCollected, encoding: .utf8) ?? ""
        lock.unlock()

        for line in stdoutLines {
            continuation.yield(line)
        }
        for line in stderrLines {
            continuation.yield(line)
        }

        return (terminatedByUser: wasTerminatedByUser, collectedErr: collectedErr)
    }

    private func drainLines(from buffer: inout Data, source: OutputSource, final: Bool) -> [OutputLine] {
        var lines: [OutputLine] = []

        while true {
            guard let range = buffer.firstRange(of: newline) else { break }
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(OutputLine(source: source, line: line))
            }
        }

        if final, !buffer.isEmpty {
            if let tail = String(data: buffer, encoding: .utf8) {
                lines.append(OutputLine(source: source, line: tail))
            }
            buffer.removeAll(keepingCapacity: false)
        }

        return lines
    }
}

/// Lightweight wrapper around `Process` for running the `container` CLI.
public struct ProcessRunner: Sendable {
    public let executableNameOrPath: String

    public init(executableNameOrPath: String) {
        self.executableNameOrPath = executableNameOrPath
    }

    public func resolveExecutableURL() throws -> URL {
        // Absolute/relative path explicitly provided
        if executableNameOrPath.contains("/") {
            let url = URL(fileURLWithPath: executableNameOrPath)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        // Search PATH first (when running from Terminal this usually works)
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let pathParts = envPath.split(separator: ":").map(String.init)

        // Common GUI-app-friendly fallback locations (Homebrew, etc.)
        let fallbacks = [
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/bin",
            "/opt/homebrew/bin"
        ]

        for dir in (pathParts + fallbacks) {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(executableNameOrPath)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw ProcessRunnerError.executableNotFound(executableNameOrPath)
    }

    /// Runs a command and captures stdout/stderr.
    ///
    /// - Note: This method throws when the process cannot be started. It does **not** throw for non-zero exit codes.
    public func run(_ arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:], stdin: Data? = nil) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let start = Date()
                do {
                    let execURL = try resolveExecutableURL()

                    let process = Process()
                    process.executableURL = execURL
                    process.arguments = arguments
                    if let wd = workingDirectory {
                        process.currentDirectoryURL = wd
                    }

                    var env = ProcessInfo.processInfo.environment
                    for (k, v) in environment { env[k] = v }
                    process.environment = env

                    let outPipe = Pipe()
                    let errPipe = Pipe()
                    process.standardOutput = outPipe
                    process.standardError = errPipe

                    if let stdinData = stdin {
                        let inPipe = Pipe()
                        inPipe.fileHandleForWriting.write(stdinData)
                        try? inPipe.fileHandleForWriting.close()
                        process.standardInput = inPipe
                    }

                    try process.run()

                    let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let result = CommandResult(
                        command: execURL.path,
                        arguments: arguments,
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus,
                        duration: Date().timeIntervalSince(start)
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs a command and throws if exit code != 0.
    public func runChecked(_ arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:], stdin: Data? = nil) async throws -> CommandResult {
        let res = try await run(arguments, workingDirectory: workingDirectory, environment: environment, stdin: stdin)
        if res.exitCode != 0 {
            throw ProcessRunnerError.commandFailed(
                command: res.command,
                arguments: res.arguments,
                exitCode: res.exitCode,
                stderr: res.stderr
            )
        }
        return res
    }

    /// Streams stdout/stderr lines as they arrive.
    ///
    /// Cancellation terminates the underlying process and does not surface an error.
    public func streamLines(_ arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:]) -> AsyncThrowingStream<OutputLine, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            do {
                process.executableURL = try resolveExecutableURL()
            } catch {
                continuation.finish(throwing: error)
                return
            }

            process.arguments = arguments
            if let wd = workingDirectory {
                process.currentDirectoryURL = wd
            }

            var env = ProcessInfo.processInfo.environment
            for (k, v) in environment { env[k] = v }
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let streamState = StreamLineState()

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                streamState.appendStdout(data, continuation: continuation)
            }

            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                streamState.appendStderr(data, continuation: continuation)
            }

            continuation.onTermination = { _ in
                streamState.markTerminatedByUser()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: ProcessRunnerError.failedToStart(error.localizedDescription))
                return
            }

            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                let snapshot = streamState.flushAndSnapshot(continuation: continuation)

                if snapshot.terminatedByUser {
                    continuation.finish()
                    return
                }

                if process.terminationStatus != 0 {
                    continuation.finish(throwing: ProcessRunnerError.commandFailed(
                        command: (process.executableURL?.path ?? executableNameOrPath),
                        arguments: arguments,
                        exitCode: process.terminationStatus,
                        stderr: snapshot.collectedErr
                    ))
                } else {
                    continuation.finish()
                }
            }
        }
    }
}
