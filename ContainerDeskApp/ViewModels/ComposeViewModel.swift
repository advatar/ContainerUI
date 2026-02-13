import Combine
import Foundation
import ContainerDeskCore

@MainActor
final class ComposeViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var composeFile: String = "compose.yaml"
    @Published var projectName: String = ""
    @Published var selectedService: String = ""

    @Published var isRunning: Bool = false
    @Published var outputText: String = ""
    @Published var errorMessage: String? = nil
    @Published var showingLogs: Bool = false

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    nonisolated static func composeCommandArguments(
        composeFile: String,
        projectName: String,
        subcommand: [String]
    ) -> [String] {
        var args = ["compose"]
        let file = composeFile.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = projectName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !file.isEmpty {
            args += ["-f", file]
        }
        if !project.isEmpty {
            args += ["-p", project]
        }

        args += subcommand
        return args
    }

    func up(detached: Bool = true) async {
        var subcommand = ["up"]
        if detached {
            subcommand.append("-d")
        }
        await runCompose(subcommand)
    }

    func down(removeVolumes: Bool = false) async {
        var subcommand = ["down"]
        if removeVolumes {
            subcommand.append("--volumes")
        }
        await runCompose(subcommand)
    }

    func pull() async {
        await runCompose(["pull"])
    }

    func build() async {
        await runCompose(["build"])
    }

    func ps() async {
        await runCompose(["ps", "--all"])
    }

    func openLogs() {
        errorMessage = nil
        showingLogs = true
    }

    func logsStream() async -> AsyncThrowingStream<OutputLine, Error> {
        var subcommand = ["logs", "--follow"]
        let service = selectedService.trimmingCharacters(in: .whitespacesAndNewlines)
        if !service.isEmpty {
            subcommand.append(service)
        }
        return await engine.streamDockerCompatibleCommand(composeCommand(subcommand))
    }

    var logsTitle: String {
        let project = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if project.isEmpty {
            return "Compose Logs"
        }
        return "Compose Logs (\(project))"
    }

    private func composeCommand(_ subcommand: [String]) -> [String] {
        Self.composeCommandArguments(
            composeFile: composeFile,
            projectName: projectName,
            subcommand: subcommand
        )
    }

    private func runCompose(_ subcommand: [String]) async {
        isRunning = true
        defer { isRunning = false }

        let requested = composeCommand(subcommand)

        do {
            let result = try await engine.runDockerCompatibleCommand(requested, checkExitCode: false)
            outputText = render(requestedArguments: requested, result: result)
            errorMessage = result.exitCode == 0 ? nil : "Command exited with code \(result.exitCode)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func render(requestedArguments: [String], result: CommandResult) -> String {
        var lines: [String] = []
        lines.append("$ docker \(requestedArguments.joined(separator: " "))")
        lines.append("executed: \(result.command) \(result.arguments.joined(separator: " "))")
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
}
