import SwiftUI
import ContainerDeskCore

struct SettingsView: View {
    let engine: ContainerEngine

    init(engine: ContainerEngine) {
        self.engine = engine
    }

    var body: some View {
        Form {
            Section("General") {
                Text("This is an MVP starter. Settings UI is placeholder.")
                    .foregroundStyle(.secondary)

                Toggle("Show stderr in logs by default", isOn: .constant(true))
                    .disabled(true)

                Toggle("Start services at login", isOn: .constant(false))
                    .disabled(true)
            }

            Section("Storage") {
                Text("Docker Desktop data is typically managed by Docker Desktop VM layers and user config under:\n~/.docker")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Advanced") {
                Text("Future: choose Docker CLI binary path, configure registry defaults, and tune resource limits.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Settings")
        .accessibilityIdentifier("screen-settings")
    }
}
