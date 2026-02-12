import SwiftUI
import ContainerDeskCore

@main
struct ContainerDeskDesktopApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
