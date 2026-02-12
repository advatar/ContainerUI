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
                Text("Apple Container typically stores data under: \n~/Library/Application Support/com.apple.container")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Section("Advanced") {
                Text("Future: choose `container` binary path, enable DNS management helper, configure defaults for new containers.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Settings")
    }
}
