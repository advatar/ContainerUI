import SwiftUI
import ContainerDeskCore

struct ComposeView: View {
    @StateObject private var vm: ComposeViewModel

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: ComposeViewModel(engine: engine))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compose")
                .font(.largeTitle.bold())

            Text("Docker Compose-compatible workflows powered by Apple container.")
                .foregroundStyle(.secondary)

            GroupBox("Project") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Compose file (default: compose.yaml)", text: $vm.composeFile)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("compose-file-input")

                    TextField("Project name (optional)", text: $vm.projectName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("compose-project-input")

                    TextField("Service for logs (optional)", text: $vm.selectedService)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("compose-service-input")
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Button("Up") {
                    Task { await vm.up(detached: true) }
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-up")

                Button("Down") {
                    Task { await vm.down(removeVolumes: false) }
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-down")

                Button("PS") {
                    Task { await vm.ps() }
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-ps")

                Button("Pull") {
                    Task { await vm.pull() }
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-pull")

                Button("Build") {
                    Task { await vm.build() }
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-build")

                Button("Logs") {
                    vm.openLogs()
                }
                .disabled(vm.isRunning)
                .accessibilityIdentifier("compose-logs")

                Spacer()

                if vm.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = vm.errorMessage, !error.isEmpty {
                Text(error)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            GroupBox("Output") {
                ScrollView {
                    Text(vm.outputText.isEmpty ? "No output yet." : vm.outputText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .navigationTitle("Compose")
        .accessibilityIdentifier("screen-compose")
        .sheet(isPresented: $vm.showingLogs) {
            NavigationStack {
                LogViewer(title: vm.logsTitle, makeStream: { await vm.logsStream() })
            }
        }
    }
}
