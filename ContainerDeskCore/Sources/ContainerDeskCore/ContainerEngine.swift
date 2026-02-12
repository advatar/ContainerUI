import Foundation

public actor ContainerEngine {
    private let runner: ProcessRunner

    public init(containerPath: String = "container") {
        self.runner = ProcessRunner(executableNameOrPath: containerPath)
    }

    // MARK: - System

    public func systemStart() async throws {
        _ = try await runFirstSuccessful([
            ["system", "start"]
        ])
    }

    public func systemStop() async throws {
        _ = try await runFirstSuccessful([
            ["system", "stop"]
        ])
    }

    public func systemStatus() async throws -> SystemStatus {
        let res = try await runFirstSuccessful([
            ["system", "status", "--format", "json"],
            ["system", "status", "--json"],
            ["system", "status"]
        ])

        if let obj = decodeJSONObject(res.stdout) {
            let running = obj.firstBool(forKeys: ["running", "isrunning", "active", "started"]) ?? false
            let msg = obj.firstString(forKeys: ["message", "status", "state"]) ?? (running ? "Running" : "Stopped")
            return SystemStatus(isRunning: running, message: msg)
        }

        // Text fallback
        let lower = res.stdout.lowercased()
        let running = (lower.contains("running") || lower.contains("started")) && !lower.contains("not running") && !lower.contains("stopped")
        let msg = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return SystemStatus(isRunning: running, message: msg.isEmpty ? (running ? "Running" : "Stopped") : msg)
    }

    public func systemLogs(follow: Bool = true) -> AsyncThrowingStream<OutputLine, Error> {
        var args = ["system", "logs"]
        if follow { args.append("--follow") }
        return runner.streamLines(args)
    }

    // MARK: - Containers

    public func listContainers(all: Bool = true) async throws -> [ContainerSummary] {
        var candidates: [[String]] = []

        // Prefer json output
        if all {
            candidates.append(["list", "--all", "--format", "json"])
            candidates.append(["list", "-a", "--format", "json"])
            candidates.append(["ls", "--all", "--format", "json"])
            candidates.append(["ls", "-a", "--format", "json"])
        } else {
            candidates.append(["list", "--format", "json"])
            candidates.append(["ls", "--format", "json"])
        }

        // Text fallback
        if all {
            candidates.append(["list", "--all"])
            candidates.append(["list", "-a"])
            candidates.append(["ls", "-a"])
        } else {
            candidates.append(["list"])
            candidates.append(["ls"])
        }

        let res = try await runFirstSuccessful(candidates)

        if let list = decodeJSONArrayOfObjects(res.stdout) {
            return list.map { ContainerSummary(raw: $0) }
        }

        // Minimal fallback: return empty but keep stderr message if helpful
        return []
    }

    public func startContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["start", id]
        ])
    }

    public func stopContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["stop", id]
        ])
    }

    public func killContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["kill", id]
        ])
    }

    public func deleteContainer(id: String, force: Bool = false) async throws {
        var a1 = ["delete"]
        if force { a1.append("--force") }
        a1.append(id)

        var a2 = ["rm"]
        if force { a2.append("--force") }
        a2.append(id)

        _ = try await runFirstSuccessful([a1, a2])
    }

    public func inspectContainer(id: String) async throws -> String {
        let res = try await runFirstSuccessful([
            ["inspect", id, "--format", "json"],
            ["inspect", id]
        ])
        return res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func containerLogs(id: String, follow: Bool = true, boot: Bool = false) -> AsyncThrowingStream<OutputLine, Error> {
        var args = ["logs"]
        if follow { args.append("--follow") }
        if boot { args.append("--boot") }
        args.append(id)
        return runner.streamLines(args)
    }

    // MARK: - Images

    public func listImages() async throws -> [ImageSummary] {
        let res = try await runFirstSuccessful([
            ["image", "list", "--format", "json"],
            ["image", "ls", "--format", "json"],
            ["image", "list"],
            ["image", "ls"]
        ])

        if let list = decodeJSONArrayOfObjects(res.stdout) {
            return list.map { ImageSummary(raw: $0) }
        }
        return []
    }

    public func pullImage(_ reference: String) async throws {
        _ = try await runFirstSuccessful([
            ["image", "pull", reference]
        ])
    }

    public func deleteImage(_ referenceOrID: String, force: Bool = false) async throws {
        var a1 = ["image", "delete"]
        if force { a1.append("--force") }
        a1.append(referenceOrID)

        var a2 = ["image", "rm"]
        if force { a2.append("--force") }
        a2.append(referenceOrID)

        _ = try await runFirstSuccessful([a1, a2])
    }

    public func inspectImage(_ referenceOrID: String) async throws -> String {
        let res = try await runFirstSuccessful([
            ["image", "inspect", referenceOrID, "--format", "json"],
            ["image", "inspect", referenceOrID]
        ])
        return res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Builder

    public func builderStatus() async throws -> BuilderStatus {
        let res = try await runFirstSuccessful([
            ["builder", "status", "--json"],
            ["builder", "status", "--format", "json"],
            ["builder", "status"]
        ])

        if let obj = decodeJSONObject(res.stdout) {
            let running = obj.firstBool(forKeys: ["running", "isrunning", "active", "started"]) ?? false
            let msg = obj.firstString(forKeys: ["message", "status", "state"]) ?? (running ? "Running" : "Stopped")
            return BuilderStatus(isRunning: running, message: msg, raw: .object(obj))
        }

        // Text fallback
        let lower = res.stdout.lowercased()
        let running = lower.contains("running") && !lower.contains("stopped")
        let msg = res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return BuilderStatus(isRunning: running, message: msg.isEmpty ? (running ? "Running" : "Stopped") : msg)
    }

    public func builderStart(cpus: Int? = nil, memory: String? = nil) async throws {
        var args = ["builder", "start"]
        if let cpus { args += ["--cpus", String(cpus)] }
        if let memory { args += ["--memory", memory] }
        _ = try await runFirstSuccessful([args])
    }

    public func builderStop() async throws {
        _ = try await runFirstSuccessful([
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
                } else {
                    lastError = ProcessRunnerError.commandFailed(
                        command: res.command,
                        arguments: res.arguments,
                        exitCode: res.exitCode,
                        stderr: res.stderr
                    )
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? ProcessRunnerError.failedToStart("No candidate command succeeded.")
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
}
