import Combine
import Foundation
import ContainerDeskCore

@MainActor
final class ContainersViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var isLoading: Bool = false
    @Published var containers: [ContainerSummary] = []
    @Published var errorMessage: String? = nil

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            containers = try await engine.listContainers(all: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start(_ c: ContainerSummary) async {
        await run { [self] in
            try await self.engine.startContainer(id: c.id)
        }
    }

    func stop(_ c: ContainerSummary) async {
        await run { [self] in
            try await self.engine.stopContainer(id: c.id)
        }
    }

    func kill(_ c: ContainerSummary) async {
        await run { [self] in
            try await self.engine.killContainer(id: c.id)
        }
    }

    func delete(_ c: ContainerSummary, force: Bool = false) async {
        await run { [self] in
            try await self.engine.deleteContainer(id: c.id, force: force)
        }
    }

    func inspect(_ c: ContainerSummary) async throws -> String {
        try await engine.inspectContainer(id: c.id)
    }

    func logsStream(for c: ContainerSummary, follow: Bool = true, boot: Bool = false) async -> AsyncThrowingStream<OutputLine, Error> {
        await engine.containerLogs(id: c.id, follow: follow, boot: boot)
    }

    // MARK: - Helpers
    private func run(_ op: @escaping () async throws -> Void) async {
        do {
            try await op()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
