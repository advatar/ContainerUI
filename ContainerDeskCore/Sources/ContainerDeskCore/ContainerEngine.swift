import Foundation

public actor ContainerEngine {
    private let runner: ProcessRunner
    public let executableNameOrPath: String

    public init(containerPath: String = "docker") {
        self.executableNameOrPath = containerPath
        self.runner = ProcessRunner(executableNameOrPath: containerPath)
    }

    // MARK: - Generic Commands

    public func runCommand(
        _ arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        stdin: Data? = nil,
        checkExitCode: Bool = true
    ) async throws -> CommandResult {
        let result = try await runner.run(
            arguments,
            workingDirectory: workingDirectory,
            environment: environment,
            stdin: stdin
        )

        if checkExitCode, result.exitCode != 0 {
            throw ProcessRunnerError.commandFailed(
                command: result.command,
                arguments: result.arguments,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return result
    }

    public func streamCommand(
        _ arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) -> AsyncThrowingStream<OutputLine, Error> {
        runner.streamLines(arguments, workingDirectory: workingDirectory, environment: environment)
    }

    // MARK: - System

    public func systemStart() async throws {
        _ = try await runFirstSuccessful([
            ["desktop", "start"],
            ["system", "start"]
        ])
    }

    public func systemStop() async throws {
        _ = try await runFirstSuccessful([
            ["desktop", "stop"],
            ["system", "stop"]
        ])
    }

    public func systemStatus() async throws -> SystemStatus {
        let res = try await runFirstSuccessful([
            ["info", "--format", "{{json .}}"],
            ["info", "--format", "json"],
            ["info"],
            ["system", "status", "--format", "json"],
            ["system", "status", "--json"],
            ["system", "status"]
        ])

        if let obj = decodeJSONObject(res.stdout) {
            let running = obj.firstBool(forKeys: ["running", "isrunning", "active", "started"]) ?? true
            let msg = obj.firstString(forKeys: ["message", "status", "state", "serverversion", "name"])
                ?? (running ? "Running" : "Stopped")
            return SystemStatus(isRunning: running, message: msg)
        }

        let msg = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = msg.lowercased()
        let running = !lower.contains("cannot connect") &&
            !lower.contains("not running") &&
            !lower.contains("connection refused") &&
            !lower.contains("error")

        return SystemStatus(isRunning: running, message: msg.isEmpty ? (running ? "Running" : "Stopped") : msg)
    }

    public func systemLogs(follow: Bool = true) -> AsyncThrowingStream<OutputLine, Error> {
        var dockerEvents = ["events"]
        if !follow {
            dockerEvents += ["--since", "10m"]
        }

        var legacyLogs = ["system", "logs"]
        if follow {
            legacyLogs.append("--follow")
        }

        return streamFirstSuccessful([dockerEvents, legacyLogs])
    }

    // MARK: - Containers

    public func listContainers(all: Bool = true) async throws -> [ContainerSummary] {
        var candidates: [[String]] = []

        if all {
            candidates += [
                ["ps", "--all", "--format", "{{json .}}"],
                ["ps", "-a", "--format", "{{json .}}"],
                ["container", "ls", "--all", "--format", "{{json .}}"],
                ["container", "ls", "-a", "--format", "{{json .}}"],
                ["list", "--all", "--format", "json"],
                ["ls", "--all", "--format", "json"],
                ["list", "-a", "--format", "json"],
                ["ls", "-a", "--format", "json"],
            ]
        } else {
            candidates += [
                ["ps", "--format", "{{json .}}"],
                ["container", "ls", "--format", "{{json .}}"],
                ["list", "--format", "json"],
                ["ls", "--format", "json"],
            ]
        }

        if all {
            candidates += [
                ["ps", "-a"],
                ["container", "ls", "-a"],
                ["list", "--all"],
                ["list", "-a"],
                ["ls", "-a"],
            ]
        } else {
            candidates += [
                ["ps"],
                ["container", "ls"],
                ["list"],
                ["ls"],
            ]
        }

        let res = try await runFirstSuccessful(candidates)

        if let list = decodeJSONArrayOfObjects(res.stdout) ?? decodeJSONObjectsFromLines(res.stdout) {
            return list.map { ContainerSummary(raw: $0) }
        }

        return []
    }

    public func startContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["container", "start", id],
            ["start", id]
        ])
    }

    public func stopContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["container", "stop", id],
            ["stop", id]
        ])
    }

    public func killContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["container", "kill", id],
            ["kill", id]
        ])
    }

    public func deleteContainer(id: String, force: Bool = false) async throws {
        var rm = ["rm"]
        if force { rm.append("--force") }
        rm.append(id)

        var containerRM = ["container", "rm"]
        if force { containerRM.append("--force") }
        containerRM.append(id)

        var legacyDelete = ["delete"]
        if force { legacyDelete.append("--force") }
        legacyDelete.append(id)

        _ = try await runFirstSuccessful([containerRM, rm, legacyDelete])
    }

    public func inspectContainer(id: String) async throws -> String {
        let res = try await runFirstSuccessful([
            ["container", "inspect", id, "--format", "json"],
            ["container", "inspect", id],
            ["inspect", id, "--format", "json"],
            ["inspect", id]
        ])
        return res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func containerLogs(id: String, follow: Bool = true, boot: Bool = false) -> AsyncThrowingStream<OutputLine, Error> {
        var dockerArgs = ["logs"]
        if follow { dockerArgs.append("--follow") }
        dockerArgs.append(id)

        var legacyArgs = ["logs"]
        if follow { legacyArgs.append("--follow") }
        if boot { legacyArgs.append("--boot") }
        legacyArgs.append(id)

        return streamFirstSuccessful([dockerArgs, legacyArgs])
    }

    // MARK: - Images

    public func listImages() async throws -> [ImageSummary] {
        let res = try await runFirstSuccessful([
            ["images", "--format", "{{json .}}"],
            ["image", "ls", "--format", "{{json .}}"],
            ["image", "list", "--format", "json"],
            ["image", "ls", "--format", "json"],
            ["images"],
            ["image", "list"],
            ["image", "ls"]
        ])

        if let list = decodeJSONArrayOfObjects(res.stdout) ?? decodeJSONObjectsFromLines(res.stdout) {
            return list.map { ImageSummary(raw: $0) }
        }
        return []
    }

    public func pullImage(_ reference: String) async throws {
        _ = try await runFirstSuccessful([
            ["pull", reference],
            ["image", "pull", reference]
        ])
    }

    public func deleteImage(_ referenceOrID: String, force: Bool = false) async throws {
        var rmi = ["rmi"]
        if force { rmi.append("--force") }
        rmi.append(referenceOrID)

        var imageRM = ["image", "rm"]
        if force { imageRM.append("--force") }
        imageRM.append(referenceOrID)

        var imageDelete = ["image", "delete"]
        if force { imageDelete.append("--force") }
        imageDelete.append(referenceOrID)

        _ = try await runFirstSuccessful([rmi, imageRM, imageDelete])
    }

    public func inspectImage(_ referenceOrID: String) async throws -> String {
        let res = try await runFirstSuccessful([
            ["image", "inspect", referenceOrID, "--format", "json"],
            ["image", "inspect", referenceOrID],
            ["inspect", referenceOrID, "--format", "json"],
            ["inspect", referenceOrID]
        ])
        return res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Builder

    public func builderStatus() async throws -> BuilderStatus {
        let res = try await runFirstSuccessful([
            ["buildx", "ls", "--format", "{{json .}}"],
            ["builder", "ls", "--format", "{{json .}}"],
            ["buildx", "ls"],
            ["builder", "ls"],
            ["builder", "status", "--json"],
            ["builder", "status", "--format", "json"],
            ["builder", "status"]
        ])

        if let obj = decodeJSONObject(res.stdout) {
            let running = obj.firstBool(forKeys: ["running", "isrunning", "active", "started"]) ?? false
            let msg = obj.firstString(forKeys: ["message", "status", "state"])
                ?? (running ? "Running" : "Stopped")
            return BuilderStatus(isRunning: running, message: msg, raw: .object(obj))
        }

        if let list = decodeJSONArrayOfObjects(res.stdout) ?? decodeJSONObjectsFromLines(res.stdout), !list.isEmpty {
            let statusStrings = list.compactMap {
                $0.firstString(forKeys: ["status", "state", "name", "driver"])
            }

            let running = statusStrings.contains { value in
                let lower = value.lowercased()
                return lower.contains("running") || lower.contains("active")
            }

            let message = statusStrings.isEmpty
                ? "\(list.count) builder(s) detected"
                : statusStrings.joined(separator: " | ")

            return BuilderStatus(isRunning: running, message: message, raw: .array(list.map { .object($0) }))
        }

        let lower = res.stdout.lowercased()
        let running = lower.contains("running") || lower.contains("active")
        let msg = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return BuilderStatus(isRunning: running, message: msg.isEmpty ? (running ? "Running" : "Stopped") : msg)
    }

    public func builderStart(cpus: Int? = nil, memory: String? = nil) async throws {
        var legacyArgs = ["builder", "start"]
        if let cpus { legacyArgs += ["--cpus", String(cpus)] }
        if let memory { legacyArgs += ["--memory", memory] }

        _ = try await runFirstSuccessful([
            ["buildx", "inspect", "--bootstrap"],
            legacyArgs
        ])
    }

    public func builderStop() async throws {
        _ = try await runFirstSuccessful([
            ["buildx", "stop"],
            ["buildx", "stop", "default"],
            ["builder", "stop"]
        ])
    }

    // MARK: - Helpers

    private func runFirstSuccessful(_ candidates: [[String]]) async throws -> CommandResult {
        var lastError: Error?

        for args in candidates {
            do {
                let res = try await runner.run(args)
                if res.exitCode == 0 {
                    return res
                }

                lastError = ProcessRunnerError.commandFailed(
                    command: res.command,
                    arguments: res.arguments,
                    exitCode: res.exitCode,
                    stderr: res.stderr
                )
            } catch {
                lastError = error
            }
        }

        throw lastError ?? ProcessRunnerError.failedToStart("No candidate command succeeded.")
    }

    private func streamFirstSuccessful(_ candidates: [[String]]) -> AsyncThrowingStream<OutputLine, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var lastError: Error?

                for args in candidates {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    do {
                        let stream = runner.streamLines(args)
                        for try await line in stream {
                            if Task.isCancelled {
                                continuation.finish()
                                return
                            }
                            continuation.yield(line)
                        }

                        continuation.finish()
                        return
                    } catch {
                        lastError = error
                    }
                }

                continuation.finish(throwing: lastError ?? ProcessRunnerError.failedToStart("No candidate command succeeded."))
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func decodeJSONArrayOfObjects(_ stdout: String) -> [[String: JSONValue]]? {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "[" else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([[String: JSONValue]].self, from: data)
    }

    private func decodeJSONObject(_ stdout: String) -> [String: JSONValue]? {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    private func decodeJSONObjectsFromLines(_ stdout: String) -> [[String: JSONValue]]? {
        var objects: [[String: JSONValue]] = []

        for rawLine in stdout.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.first == "{" else { return nil }
            guard let data = line.data(using: .utf8),
                  let object = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
                return nil
            }
            objects.append(object)
        }

        return objects.isEmpty ? nil : objects
    }
}
