import Foundation
import ContainerDeskCore

struct DockerCommand: Identifiable, Hashable, Sendable {
    let name: String
    let summary: String
    let example: String

    var id: String { name }
}

struct DockerCommandSection: Identifiable, Hashable, Sendable {
    let title: String
    let commands: [DockerCommand]

    var id: String { title }
}

enum DockerCommandCatalog {
    static let sections: [DockerCommandSection] = [
        DockerCommandSection(title: "Common", commands: [
            DockerCommand(name: "run", summary: "Create and run a new container from an image", example: "run --rm hello-world"),
            DockerCommand(name: "exec", summary: "Execute a command in a running container", example: "exec -it <container> /bin/sh"),
            DockerCommand(name: "ps", summary: "List containers", example: "ps --all"),
            DockerCommand(name: "build", summary: "Build an image from a Dockerfile", example: "build -t my-image ."),
            DockerCommand(name: "pull", summary: "Download an image from a registry", example: "pull nginx:latest"),
            DockerCommand(name: "push", summary: "Upload an image to a registry", example: "push my-registry/my-image:latest"),
            DockerCommand(name: "images", summary: "List images", example: "images"),
            DockerCommand(name: "login", summary: "Authenticate to a registry", example: "login"),
            DockerCommand(name: "logout", summary: "Log out from a registry", example: "logout"),
            DockerCommand(name: "search", summary: "Search Docker Hub", example: "search nginx"),
            DockerCommand(name: "version", summary: "Show Docker version information", example: "version"),
            DockerCommand(name: "info", summary: "Display system-wide information", example: "info"),
        ]),
        DockerCommandSection(title: "Management", commands: [
            DockerCommand(name: "builder", summary: "Manage builds", example: "builder ls"),
            DockerCommand(name: "buildx", summary: "Docker Buildx", example: "buildx ls"),
            DockerCommand(name: "compose", summary: "Docker Compose", example: "compose ls"),
            DockerCommand(name: "container", summary: "Manage containers", example: "container ls --all"),
            DockerCommand(name: "context", summary: "Manage contexts", example: "context ls"),
            DockerCommand(name: "image", summary: "Manage images", example: "image ls"),
            DockerCommand(name: "network", summary: "Manage networks", example: "network ls"),
            DockerCommand(name: "system", summary: "Manage Docker", example: "system df"),
            DockerCommand(name: "volume", summary: "Manage volumes", example: "volume ls"),
        ]),
        DockerCommandSection(title: "Swarm", commands: [
            DockerCommand(name: "config", summary: "Manage Swarm configs", example: "config ls"),
            DockerCommand(name: "node", summary: "Manage Swarm nodes", example: "node ls"),
            DockerCommand(name: "secret", summary: "Manage Swarm secrets", example: "secret ls"),
            DockerCommand(name: "service", summary: "Manage Swarm services", example: "service ls"),
            DockerCommand(name: "stack", summary: "Manage Swarm stacks", example: "stack ls"),
            DockerCommand(name: "swarm", summary: "Manage Swarm", example: "swarm init"),
        ]),
        DockerCommandSection(title: "Runtime", commands: [
            DockerCommand(name: "attach", summary: "Attach local streams to a running container", example: "attach <container>"),
            DockerCommand(name: "commit", summary: "Create image from container changes", example: "commit <container> my-image:latest"),
            DockerCommand(name: "cp", summary: "Copy files/folders between container and local filesystem", example: "cp <container>:/etc/hosts ./hosts"),
            DockerCommand(name: "create", summary: "Create a new container", example: "create --name web nginx:latest"),
            DockerCommand(name: "diff", summary: "Inspect filesystem changes", example: "diff <container>"),
            DockerCommand(name: "events", summary: "Get realtime events from the daemon", example: "events"),
            DockerCommand(name: "export", summary: "Export a container filesystem as tar", example: "export <container> > container.tar"),
            DockerCommand(name: "history", summary: "Show image history", example: "history nginx:latest"),
            DockerCommand(name: "import", summary: "Import filesystem image from tarball", example: "import rootfs.tar my-image:latest"),
            DockerCommand(name: "inspect", summary: "Return low-level information", example: "inspect <id>"),
            DockerCommand(name: "kill", summary: "Kill one or more running containers", example: "kill <container>"),
            DockerCommand(name: "load", summary: "Load an image from a tar archive", example: "load -i image.tar"),
            DockerCommand(name: "logs", summary: "Fetch logs of a container", example: "logs --follow <container>"),
            DockerCommand(name: "pause", summary: "Pause all processes in a container", example: "pause <container>"),
            DockerCommand(name: "port", summary: "List port mappings", example: "port <container>"),
            DockerCommand(name: "rename", summary: "Rename a container", example: "rename old-name new-name"),
            DockerCommand(name: "restart", summary: "Restart containers", example: "restart <container>"),
            DockerCommand(name: "rm", summary: "Remove containers", example: "rm <container>"),
            DockerCommand(name: "rmi", summary: "Remove images", example: "rmi <image>"),
            DockerCommand(name: "save", summary: "Save images to tar archive", example: "save -o image.tar <image>"),
            DockerCommand(name: "start", summary: "Start stopped containers", example: "start <container>"),
            DockerCommand(name: "stats", summary: "Stream container resource usage", example: "stats"),
            DockerCommand(name: "stop", summary: "Stop running containers", example: "stop <container>"),
            DockerCommand(name: "tag", summary: "Create image tag", example: "tag source:latest target:latest"),
            DockerCommand(name: "top", summary: "Display running processes in a container", example: "top <container>"),
            DockerCommand(name: "unpause", summary: "Unpause paused containers", example: "unpause <container>"),
            DockerCommand(name: "update", summary: "Update container configuration", example: "update --cpus 1 <container>"),
            DockerCommand(name: "wait", summary: "Wait for containers to stop and print exit code", example: "wait <container>"),
        ])
    ]
}

enum CommandCenterError: LocalizedError, Sendable {
    case emptyCommand

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return "Enter a Docker command."
        }
    }
}

@MainActor
final class CommandCenterViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var commandInput: String = "docker ps --all"
    @Published var outputText: String = ""
    @Published var errorMessage: String? = nil
    @Published var isRunning: Bool = false
    @Published var showingStream: Bool = false
    @Published private(set) var streamArguments: [String] = []

    let sections: [DockerCommandSection]

    init(engine: ContainerEngine, sections: [DockerCommandSection] = DockerCommandCatalog.sections) {
        self.engine = engine
        self.sections = sections
    }

    nonisolated static func normalizedArguments(from input: String) throws -> [String] {
        let tokens = try CommandLineTokenizer.tokenize(input)
        guard !tokens.isEmpty else {
            throw CommandCenterError.emptyCommand
        }

        let head = tokens[0].lowercased()
        if head == "docker" || head == "container" {
            let trimmed = Array(tokens.dropFirst())
            guard !trimmed.isEmpty else {
                throw CommandCenterError.emptyCommand
            }
            return trimmed
        }

        return tokens
    }

    func useTemplate(_ command: DockerCommand) {
        commandInput = "docker \(command.example)"
    }

    func run() async {
        isRunning = true
        defer { isRunning = false }

        do {
            let arguments = try Self.normalizedArguments(from: commandInput)
            let result = try await engine.runCommand(arguments, checkExitCode: false)
            outputText = render(result)

            if result.exitCode == 0 {
                errorMessage = nil
            } else {
                errorMessage = "Command exited with code \(result.exitCode)."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearOutput() {
        outputText = ""
        errorMessage = nil
    }

    func openStream() {
        do {
            streamArguments = try Self.normalizedArguments(from: commandInput)
            errorMessage = nil
            showingStream = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stream() async -> AsyncThrowingStream<OutputLine, Error> {
        guard !streamArguments.isEmpty else {
            return Self.failedStream(CommandCenterError.emptyCommand)
        }
        return await engine.streamCommand(streamArguments)
    }

    var streamTitle: String {
        "Stream: docker \(streamArguments.joined(separator: " "))"
    }

    private func render(_ result: CommandResult) -> String {
        var lines: [String] = []
        lines.append("$ docker \(result.arguments.joined(separator: " "))")
        lines.append("exit code: \(result.exitCode)")
        lines.append(String(format: "duration: %.2fs", result.duration))

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        if !stdout.isEmpty {
            lines.append("")
            lines.append("stdout:")
            lines.append(stdout)
        }

        if !stderr.isEmpty {
            lines.append("")
            lines.append("stderr:")
            lines.append(stderr)
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated static func failedStream(_ error: Error) -> AsyncThrowingStream<OutputLine, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}
