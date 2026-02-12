import SwiftUI
import ContainerDeskCore

struct CommandCenterView: View {
    @StateObject private var vm: CommandCenterViewModel

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: CommandCenterViewModel(engine: engine))
    }

    var body: some View {
        HSplitView {
            List {
                ForEach(vm.sections) { section in
                    Section(section.title) {
                        ForEach(section.commands) { command in
                            Button {
                                vm.useTemplate(command)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(command.name)
                                        .font(.headline)
                                    Text(command.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("docker-cmd-\(command.id)")
                        }
                    }
                }
            }
            .frame(minWidth: 320, idealWidth: 380)

            VStack(alignment: .leading, spacing: 12) {
                Text("Docker CLI Command Center")
                    .font(.title2.bold())

                Text("Every Docker CLI command is accessible here. Use the command catalog on the left or type any command directly.")
                    .foregroundStyle(.secondary)

                TextField("docker ps --all", text: $vm.commandInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityIdentifier("docker-command-input")

                HStack(spacing: 10) {
                    Button("Run Command") {
                        Task { await vm.run() }
                    }
                    .disabled(vm.isRunning)
                    .accessibilityIdentifier("docker-run-command")

                    Button("Open Stream") {
                        vm.openStream()
                    }
                    .disabled(vm.isRunning)
                    .accessibilityIdentifier("docker-open-stream")

                    Button("Clear Output") {
                        vm.clearOutput()
                    }

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
            .frame(minWidth: 500)
        }
        .navigationTitle("Docker CLI")
        .accessibilityIdentifier("screen-docker-cli")
        .sheet(isPresented: $vm.showingStream) {
            NavigationStack {
                LogViewer(title: vm.streamTitle, makeStream: { await vm.stream() })
            }
        }
    }
}
