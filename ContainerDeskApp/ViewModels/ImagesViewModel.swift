import Foundation
import ContainerDeskCore

@MainActor
final class ImagesViewModel: ObservableObject {
    private let engine: ContainerEngine

    @Published var isLoading: Bool = false
    @Published var images: [ImageSummary] = []
    @Published var errorMessage: String? = nil

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            images = try await engine.listImages()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pull(reference: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await engine.pullImage(reference)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ img: ImageSummary, force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await engine.deleteImage(img.reference, force: force)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func inspect(_ img: ImageSummary) async throws -> String {
        try await engine.inspectImage(img.reference)
    }
}
