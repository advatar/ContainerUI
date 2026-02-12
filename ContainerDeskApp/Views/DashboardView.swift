import SwiftUI
import ContainerDeskCore

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm: DashboardViewModel

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: DashboardViewModel(engine: engine))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 220), spacing: 12)
                ], spacing: 12) {
                    statCard(title: "System", value: appState.systemStatus.isRunning ? "Running" : "Stopped", systemImage: appState.systemStatus.isRunning ? "checkmark.circle" : "xmark.circle")
                    statCard(title: "Containers", value: "\(vm.runningContainers) running / \(vm.totalContainers) total", systemImage: "shippingbox")
                    statCard(title: "Images", value: "\(vm.images)", systemImage: "square.stack.3d.up")
                    statCard(title: "Builder", value: vm.builderRunning ? "Running" : "Stopped", systemImage: "hammer")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appState.systemStatus.message)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        HStack {
                            Button("Refresh") {
                                Task {
                                    await appState.refreshSystemStatus()
                                    await vm.refresh()
                                }
                            }

                            Spacer()

                            Button("Start Services") {
                                Task { await appState.systemStart() }
                            }
                            .disabled(appState.systemStatus.isRunning)

                            Button("Stop Services") {
                                Task { await appState.systemStop() }
                            }
                            .disabled(!appState.systemStatus.isRunning)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label("Service Status", systemImage: "gear")
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .accessibilityIdentifier("screen-dashboard")
        .task {
            await vm.refresh()
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("ContainerDesk")
                .font(.largeTitle.bold())
            Spacer()
            if vm.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func statCard(title: String, value: String, systemImage: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
