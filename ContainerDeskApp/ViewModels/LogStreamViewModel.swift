import Combine
import Foundation
import ContainerDeskCore

@MainActor
final class LogStreamViewModel: ObservableObject {
    struct Line: Identifiable, Hashable {
        let id = UUID()
        let source: OutputSource
        let text: String
    }

    @Published var lines: [Line] = []
    @Published var isRunning: Bool = false
    @Published var errorMessage: String? = nil

    private var task: Task<Void, Never>? = nil

    func start(stream: AsyncThrowingStream<OutputLine, Error>, maxLines: Int = 5_000) {
        stop()
        isRunning = true
        errorMessage = nil
        lines.removeAll(keepingCapacity: true)

        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    lines.append(Line(source: chunk.source, text: chunk.line))
                    if lines.count > maxLines {
                        lines.removeFirst(lines.count - maxLines)
                    }
                }
                isRunning = false
            } catch {
                if Task.isCancelled { return }
                isRunning = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

}
