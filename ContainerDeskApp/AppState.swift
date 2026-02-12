import Foundation
import SwiftUI
import ContainerDeskCore

@MainActor
final class AppState: ObservableObject {
    let engine: ContainerEngine
    private let uiTestMode: Bool

    @Published var systemStatus: SystemStatus = .unknown
    @Published var lastErrorMessage: String? = nil

    init(engine: ContainerEngine = ContainerEngine()) {
        self.engine = engine
        self.uiTestMode = ProcessInfo.processInfo.arguments.contains("UITEST_MODE")

        if uiTestMode {
            self.systemStatus = SystemStatus(isRunning: false, message: "UI test mode")
        }
    }

    func refreshSystemStatus() async {
        if uiTestMode { return }
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
