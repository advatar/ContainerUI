import Foundation

public actor ContainerEngine {
    private let runner: ProcessRunner
    public let executableNameOrPath: String

    public init(containerPath: String = "container") {
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

    /// Runs docker-compatible arguments by translating them to Apple `container` command equivalents.
    public func runDockerCompatibleCommand(
        _ dockerArguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        checkExitCode: Bool = true
    ) async throws -> CommandResult {
        guard !dockerArguments.isEmpty else {
            throw ProcessRunnerError.failedToStart("No command provided.")
        }

        let candidates = dockerCompatibleCandidates(for: dockerArguments)
        var lastFailure: CommandResult?
        var lastError: Error?

        for args in candidates {
            do {
                let result = try await runner.run(
                    args,
                    workingDirectory: workingDirectory,
                    environment: environment
                )

                if result.exitCode == 0 {
                    return result
                }

                lastFailure = result
                if isCompatibilityFallbackWorthy(stderr: result.stderr) {
                    continue
                }

                if checkExitCode {
                    throw ProcessRunnerError.commandFailed(
                        command: result.command,
                        arguments: result.arguments,
                        exitCode: result.exitCode,
                        stderr: result.stderr
                    )
                }

                return result
            } catch {
                lastError = error
            }
        }

        if let lastFailure {
            if checkExitCode {
                throw ProcessRunnerError.commandFailed(
                    command: lastFailure.command,
                    arguments: lastFailure.arguments,
                    exitCode: lastFailure.exitCode,
                    stderr: lastFailure.stderr
                )
            }
            return lastFailure
        }

        throw lastError ?? ProcessRunnerError.failedToStart("No compatibility candidates matched.")
    }

    /// Streams docker-compatible arguments by translating them to Apple `container` command equivalents.
    public func streamDockerCompatibleCommand(
        _ dockerArguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) -> AsyncThrowingStream<OutputLine, Error> {
        let candidates = dockerCompatibleCandidates(for: dockerArguments)

        return AsyncThrowingStream { continuation in
            let task = Task {
                var lastError: Error?

                for args in candidates {
                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    do {
                        let stream = runner.streamLines(
                            args,
                            workingDirectory: workingDirectory,
                            environment: environment
                        )
                        for try await line in stream {
                            if Task.isCancelled {
                                continuation.finish()
                                return
                            }
                            continuation.yield(line)
                        }

                        continuation.finish()
                        return
                    } catch let error as ProcessRunnerError {
                        switch error {
                        case .commandFailed(_, _, _, let stderr):
                            if isCompatibilityFallbackWorthy(stderr: stderr) {
                                lastError = error
                                continue
                            }
                            continuation.finish(throwing: error)
                            return
                        default:
                            lastError = error
                        }
                    } catch {
                        lastError = error
                    }
                }

                continuation.finish(throwing: lastError ?? ProcessRunnerError.failedToStart("No compatibility candidates matched."))
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - System

    public func systemStart() async throws {
        _ = try await runFirstSuccessful([
            ["system", "start"],
            ["desktop", "start"]
        ])
    }

    public func systemStop() async throws {
        _ = try await runFirstSuccessful([
            ["system", "stop"],
            ["desktop", "stop"]
        ])
    }

    public func systemStatus() async throws -> SystemStatus {
        let res = try await runFirstSuccessful([
            ["system", "status", "--format", "json"],
            ["system", "status", "--json"],
            ["system", "status"],
            ["info", "--format", "{{json .}}"],
            ["info", "--format", "json"],
            ["info"]
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
        var systemLogs = ["system", "logs"]
        if follow {
            systemLogs.append("--follow")
        }

        var dockerEvents = ["events"]
        if !follow {
            dockerEvents += ["--since", "10m"]
        }

        return streamFirstSuccessful([systemLogs, dockerEvents])
    }

    // MARK: - Containers

    public func listContainers(all: Bool = true) async throws -> [ContainerSummary] {
        var candidates: [[String]] = []

        if all {
            candidates += [
                ["list", "--all", "--format", "json"],
                ["ls", "--all", "--format", "json"],
                ["list", "-a", "--format", "json"],
                ["ls", "-a", "--format", "json"],
                ["ps", "--all", "--format", "{{json .}}"],
                ["ps", "-a", "--format", "{{json .}}"],
                ["container", "ls", "--all", "--format", "{{json .}}"],
                ["container", "ls", "-a", "--format", "{{json .}}"],
            ]
        } else {
            candidates += [
                ["list", "--format", "json"],
                ["ls", "--format", "json"],
                ["ps", "--format", "{{json .}}"],
                ["container", "ls", "--format", "{{json .}}"],
            ]
        }

        if all {
            candidates += [
                ["list", "--all"],
                ["list", "-a"],
                ["ls", "-a"],
                ["ps", "-a"],
                ["container", "ls", "-a"],
            ]
        } else {
            candidates += [
                ["list"],
                ["ls"],
                ["ps"],
                ["container", "ls"],
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
            ["start", id],
            ["container", "start", id]
        ])
    }

    public func stopContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["stop", id],
            ["container", "stop", id]
        ])
    }

    public func killContainer(id: String) async throws {
        _ = try await runFirstSuccessful([
            ["kill", id],
            ["container", "kill", id]
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

        _ = try await runFirstSuccessful([legacyDelete, containerRM, rm])
    }

    public func inspectContainer(id: String) async throws -> String {
        let res = try await runFirstSuccessful([
            ["inspect", id, "--format", "json"],
            ["inspect", id],
            ["container", "inspect", id, "--format", "json"],
            ["container", "inspect", id],
        ])
        return res.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func containerLogs(id: String, follow: Bool = true, boot: Bool = false) -> AsyncThrowingStream<OutputLine, Error> {
        var legacyArgs = ["logs"]
        if follow { legacyArgs.append("--follow") }
        if boot { legacyArgs.append("--boot") }
        legacyArgs.append(id)

        var dockerArgs = ["logs"]
        if follow { dockerArgs.append("--follow") }
        dockerArgs.append(id)

        return streamFirstSuccessful([legacyArgs, dockerArgs])
    }

    // MARK: - Images

    public func listImages() async throws -> [ImageSummary] {
        let res = try await runFirstSuccessful([
            ["image", "list", "--format", "json"],
            ["image", "ls", "--format", "json"],
            ["images", "--format", "{{json .}}"],
            ["image", "ls", "--format", "{{json .}}"],
            ["image", "list"],
            ["image", "ls"],
            ["images"]
        ])

        if let list = decodeJSONArrayOfObjects(res.stdout) ?? decodeJSONObjectsFromLines(res.stdout) {
            return list.map { ImageSummary(raw: $0) }
        }
        return []
    }

    public func pullImage(_ reference: String) async throws {
        _ = try await runFirstSuccessful([
            ["image", "pull", reference],
            ["pull", reference]
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

        _ = try await runFirstSuccessful([imageDelete, imageRM, rmi])
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
            ["builder", "status", "--json"],
            ["builder", "status", "--format", "json"],
            ["builder", "status"],
            ["builder", "ls", "--format", "{{json .}}"],
            ["builder", "ls"],
            ["buildx", "ls", "--format", "{{json .}}"],
            ["buildx", "ls"],
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

    // MARK: - Docker Compatibility Translation

    private func dockerCompatibleCandidates(for dockerArguments: [String]) -> [[String]] {
        guard let head = dockerArguments.first else { return [] }
        let tail = Array(dockerArguments.dropFirst())

        let mapped: [[String]]
        switch head.lowercased() {
        case "ps":
            mapped = [
                ["list"] + tail,
                ["ls"] + tail,
                ["ps"] + tail,
            ]
        case "images":
            mapped = [
                ["image", "list"] + tail,
                ["image", "ls"] + tail,
                ["images"] + tail,
            ]
        case "rm":
            mapped = [
                ["delete"] + tail,
                ["rm"] + tail,
            ]
        case "rmi":
            mapped = [
                ["image", "delete"] + tail,
                ["image", "rm"] + tail,
                ["rmi"] + tail,
            ]
        case "info":
            mapped = [
                ["system", "status"],
                ["info"] + tail,
            ]
        case "compose":
            mapped = [
                ["compose"] + tail,
                ["system", "compose"] + tail,
            ]
        case "container":
            mapped = dockerCompatibleContainerSubcommands(tail)
        case "image":
            mapped = dockerCompatibleImageSubcommands(tail)
        case "system":
            mapped = dockerCompatibleSystemSubcommands(tail)
        case "buildx", "builder":
            mapped = dockerCompatibleBuilderSubcommands(head: head, tail: tail)
        default:
            mapped = [dockerArguments]
        }

        return deduplicateCandidates(mapped + [dockerArguments])
    }

    private func dockerCompatibleContainerSubcommands(_ tail: [String]) -> [[String]] {
        guard let sub = tail.first?.lowercased() else {
            return [["list"], ["ls"], ["container", "ls"]]
        }

        let rest = Array(tail.dropFirst())
        switch sub {
        case "ls", "list", "ps":
            return [
                ["list"] + rest,
                ["ls"] + rest,
                ["container", "ls"] + rest,
            ]
        case "rm", "delete":
            return [
                ["delete"] + rest,
                ["container", "rm"] + rest,
                ["rm"] + rest,
            ]
        case "inspect", "start", "stop", "kill", "logs", "exec", "cp", "diff", "restart", "wait":
            return [
                [sub] + rest,
                ["container", sub] + rest,
            ]
        default:
            return [
                ["container"] + tail,
                [sub] + rest,
            ]
        }
    }

    private func dockerCompatibleImageSubcommands(_ tail: [String]) -> [[String]] {
        guard let sub = tail.first?.lowercased() else {
            return [["image", "list"], ["image", "ls"]]
        }

        let rest = Array(tail.dropFirst())
        switch sub {
        case "ls", "list":
            return [
                ["image", "list"] + rest,
                ["image", "ls"] + rest,
                ["images"] + rest,
            ]
        case "rm", "rmi", "delete":
            return [
                ["image", "delete"] + rest,
                ["image", "rm"] + rest,
                ["rmi"] + rest,
            ]
        case "pull", "inspect":
            return [
                ["image", sub] + rest,
                [sub] + rest,
            ]
        default:
            return [["image"] + tail]
        }
    }

    private func dockerCompatibleSystemSubcommands(_ tail: [String]) -> [[String]] {
        guard let sub = tail.first?.lowercased() else {
            return [["system", "status"], ["info"]]
        }

        let rest = Array(tail.dropFirst())
        switch sub {
        case "start", "stop", "status", "logs":
            return [
                ["system", sub] + rest,
            ]
        default:
            return [
                ["system"] + tail,
                ["info"],
            ]
        }
    }

    private func dockerCompatibleBuilderSubcommands(head: String, tail: [String]) -> [[String]] {
        guard let sub = tail.first?.lowercased() else {
            return [
                ["builder", "status"],
                ["buildx", "ls"],
            ]
        }

        let rest = Array(tail.dropFirst())
        switch sub {
        case "ls", "list":
            return [
                ["builder", "status"],
                ["builder", "ls"] + rest,
                ["buildx", "ls"] + rest,
            ]
        case "stop":
            return [
                ["builder", "stop"] + rest,
                ["buildx", "stop"] + rest,
            ]
        case "start":
            return [
                ["builder", "start"] + rest,
                ["buildx", "inspect", "--bootstrap"],
            ]
        default:
            return [
                [head] + tail,
                ["builder"] + tail,
                ["buildx"] + tail,
            ]
        }
    }

    private func deduplicateCandidates(_ candidates: [[String]]) -> [[String]] {
        var seen = Set<String>()
        var unique: [[String]] = []

        for args in candidates where !args.isEmpty {
            let key = args.joined(separator: "\u{1F}")
            if seen.insert(key).inserted {
                unique.append(args)
            }
        }

        return unique
    }

    private func isCompatibilityFallbackWorthy(stderr: String) -> Bool {
        let lower = stderr.lowercased()
        return lower.contains("unknown command")
            || lower.contains("no such command")
            || lower.contains("unknown shorthand flag")
            || lower.contains("unknown flag")
            || lower.contains("flag provided but not defined")
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
