import SwiftUI
import ContainerDeskCore

struct TroubleshootView: View {
    let engine: ContainerEngine
    @EnvironmentObject private var appState: AppState

    @State private var showingSystemLogs: Bool = false

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Troubleshoot")
                .font(.largeTitle.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.systemStatus.isRunning ? "Services are running." : "Services are stopped.")
                        .font(.headline)

                    Text(appState.systemStatus.message)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    HStack {
                        Button("Refresh Status") {
                            Task { await appState.refreshSystemStatus() }
                        }

                        Button("View System Logs") {
                            showingSystemLogs = true
                        }

                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("System", systemImage: "gear")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick checks")
                        .font(.headline)

                    Text("• Try: `container system status`\n• If commands fail from the app but work in Terminal, it’s usually PATH.\n• For service lifecycle, try: `container system start` / `container system stop`.")
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 4)
            } label: {
                Label("Notes", systemImage: "info.circle")
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Troubleshoot")
        .accessibilityIdentifier("screen-troubleshoot")
        .sheet(isPresented: $showingSystemLogs) {
            NavigationStack {
                LogViewer(title: "System Logs", makeStream: { await engine.systemLogs(follow: true) })
            }
        }
    }
}
