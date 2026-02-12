import SwiftUI
import ContainerDeskCore

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case containers = "Containers"
    case images = "Images"
    case builds = "Builds"
    case dockerCLI = "Docker CLI"
    case troubleshoot = "Troubleshoot"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "speedometer"
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .builds: return "hammer"
        case .dockerCLI: return "terminal"
        case .troubleshoot: return "stethoscope"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: NavItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(NavItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item as NavItem?)
                    .accessibilityIdentifier("nav-\(item.id)")
            }
            .navigationTitle("ContainerDesk")
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(engine: appState.engine)
                case .containers:
                    ContainersView(engine: appState.engine)
                case .images:
                    ImagesView(engine: appState.engine)
                case .builds:
                    BuildsView(engine: appState.engine)
                case .dockerCLI:
                    CommandCenterView(engine: appState.engine)
                case .troubleshoot:
                    TroubleshootView(engine: appState.engine)
                case .settings:
                    SettingsView(engine: appState.engine)
                }
            }
            .frame(minWidth: 720, minHeight: 480)
        }
        .task {
            await appState.refreshSystemStatus()
        }
        .alert("Error", isPresented: Binding(
            get: { appState.lastErrorMessage != nil },
            set: { if !$0 { appState.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.lastErrorMessage = nil }
        } message: {
            Text(appState.lastErrorMessage ?? "")
        }
    }
}
