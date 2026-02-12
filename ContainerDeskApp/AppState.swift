import Foundation
import SwiftUI
import ContainerDeskCore

@MainActor
final class AppState: ObservableObject {
    let engine: ContainerEngine

    @Published var systemStatus: SystemStatus = .unknown
    @Published var lastErrorMessage: String? = nil

    init(engine: ContainerEngine = ContainerEngine()) {
        self.engine = engine
    }

    func refreshSystemStatus() async {
        do {
            systemStatus = try await engine.systemStatus()
        } catch {
            systemStatus = SystemStatus(isRunning: false, message: "Unavailable")
            lastErrorMessage = error.localizedDescription
        }
    }

    func systemStart() async {
        do {
            try await engine.systemStart()
            await refreshSystemStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func systemStop() async {
        do {
            try await engine.systemStop()
            await refreshSystemStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
