import Combine
import Foundation
import ContainerDeskCore

@MainActor
final class DashboardViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var isLoading: Bool = false
    @Published var runningContainers: Int = 0
    @Published var totalContainers: Int = 0
    @Published var images: Int = 0
    @Published var builderMessage: String = "—"
    @Published var builderRunning: Bool = false
    @Published var errorMessage: String? = nil

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let containers = try await engine.listContainers(all: true)
            totalContainers = containers.count
            runningContainers = containers.filter { $0.state == .running }.count

            let imgs = try await engine.listImages()
            images = imgs.count

            let b = try await engine.builderStatus()
            builderRunning = b.isRunning
            builderMessage = b.message.isEmpty ? (b.isRunning ? "Running" : "Stopped") : b.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
