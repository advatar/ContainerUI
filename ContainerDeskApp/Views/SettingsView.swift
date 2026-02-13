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
                Text("Apple container data and config are managed by the `container` runtime and user-level configuration paths.")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Advanced") {
                Text("Future: choose container binary path, configure compatibility behavior, and tune resource limits.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Settings")
        .accessibilityIdentifier("screen-settings")
    }
}
