import Foundation
import ContainerDeskCore

@MainActor
final class BuildsViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var isLoading: Bool = false
    @Published var builderRunning: Bool = false
    @Published var builderMessage: String = "—"
    @Published var errorMessage: String? = nil

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let b = try await engine.builderStatus()
            builderRunning = b.isRunning
            builderMessage = b.message.isEmpty ? (b.isRunning ? "Running" : "Stopped") : b.message
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func start() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await engine.builderStart(cpus: nil, memory: nil)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await engine.builderStop()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
