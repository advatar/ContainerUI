import SwiftUI
import ContainerDeskCore

struct BuildsView: View {
    @StateObject private var vm: BuildsViewModel

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: BuildsViewModel(engine: engine))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Builder")
                    .font(.largeTitle.bold())
                Spacer()
                if vm.isLoading { ProgressView().controlSize(.small) }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(vm.builderRunning ? "Running" : "Stopped", systemImage: vm.builderRunning ? "checkmark.circle" : "xmark.circle")
                        Spacer()
                        Button("Refresh") { Task { await vm.refresh() } }
                    }

                    Text(vm.builderMessage)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    HStack {
                        Button("Start") { Task { await vm.start() } }
                            .disabled(vm.builderRunning)
                        Button("Stop") { Task { await vm.stop() } }
                            .disabled(!vm.builderRunning)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Status", systemImage: "hammer")
            }

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Builds")
        .accessibilityIdentifier("screen-builds")
        .task { await vm.refresh() }
    }
}
