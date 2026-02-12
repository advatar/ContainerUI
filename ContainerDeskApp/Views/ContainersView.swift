import SwiftUI
import ContainerDeskCore

struct ContainersView: View {
    @StateObject private var vm: ContainersViewModel
    @State private var searchText: String = ""
    @State private var selectedContainerID: String? = nil

    @State private var showingLogs: Bool = false
    @State private var showingInspect: Bool = false
    @State private var inspectText: String = ""

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: ContainersViewModel(engine: engine))
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedContainerID) {
                    ForEach(filtered) { c in
                        HStack(spacing: 10) {
                            Image(systemName: c.state == .running ? "play.fill" : "stop.fill")
                                .foregroundStyle(c.state == .running ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name)
                                    .font(.headline)
                                Text(c.image)
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }

                            Spacer()

                            Text(c.status)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(c.id as String?)
                        .contextMenu {
                            contextMenu(for: c)
                        }
                    }
                }
                .searchable(text: $searchText)
                .overlay(alignment: .topTrailing) {
                    if vm.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .frame(minWidth: 320, idealWidth: 380)

            Divider()

            detailPanel
                .frame(minWidth: 380)
        }
        .navigationTitle("Containers")
        .accessibilityIdentifier("screen-containers")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Spacer()

                if let selected = selectedContainer {
                    Button {
                        TerminalLauncher.runInTerminal("container exec -it \(selected.id) /bin/sh")
                    } label: {
                        Label("Exec", systemImage: "terminal")
                    }
                }
            }
        }
        .task {
            await vm.refresh()
        }
        .sheet(isPresented: $showingLogs) {
            if let selected = selectedContainer {
                NavigationStack {
                    LogViewer(
                        title: "Logs: \(selected.name)",
                        makeStream: { await vm.logsStream(for: selected, follow: true, boot: false) }
                    )
                }
            } else {
                Text("No container selected.")
                    .padding()
            }
        }
        .sheet(isPresented: $showingInspect) {
            NavigationStack {
                TextInspectorView(title: "Inspect", text: inspectText)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private var filtered: [ContainerSummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.containers }
        return vm.containers.filter { c in
            c.name.lowercased().contains(q) ||
            c.image.lowercased().contains(q) ||
            c.id.lowercased().contains(q)
        }
    }

    private var selectedContainer: ContainerSummary? {
        guard let id = selectedContainerID else { return nil }
        return vm.containers.first(where: { $0.id == id })
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let c = selectedContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text(c.name)
                            .font(.title.bold())
                        Spacer()
                        statePill(for: c)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            keyValue("ID", c.id)
                            keyValue("Image", c.image)
                            keyValue("Status", c.status)
                            if let created = c.createdAt { keyValue("Created", created) }
                            if let ports = c.ports { keyValue("Ports", ports) }
                            if let ip = c.ipAddress { keyValue("IP", ip) }
                        }
                        .textSelection(.enabled)
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }

                    HStack(spacing: 10) {
                        Button("Start") { Task { await vm.start(c) } }
                            .disabled(c.state == .running)
                        Button("Stop") { Task { await vm.stop(c) } }
                            .disabled(c.state != .running)
                        Button("Logs") { showingLogs = true }
                        Button("Inspect") {
                            Task {
                                do {
                                    inspectText = try await vm.inspect(c)
                                    showingInspect = true
                                } catch {
                                    vm.errorMessage = error.localizedDescription
                                }
                            }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            Task { await vm.delete(c, force: false) }
                        } label: {
                            Text("Delete")
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
        } else {
            ContentUnavailableView("Select a container", systemImage: "shippingbox", description: Text("Choose a container from the list to see details."))
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }

    private func statePill(for c: ContainerSummary) -> some View {
        let text = c.state == .running ? "Running" : "Stopped"
        let icon = c.state == .running ? "play.fill" : "stop.fill"

        return Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func contextMenu(for c: ContainerSummary) -> some View {
        Button("Logs") {
            selectedContainerID = c.id
            showingLogs = true
        }

        Button("Inspect") {
            selectedContainerID = c.id
            Task {
                do {
                    inspectText = try await vm.inspect(c)
                    showingInspect = true
                } catch {
                    vm.errorMessage = error.localizedDescription
                }
            }
        }

        Divider()

        if c.state == .running {
            Button("Stop") { Task { await vm.stop(c) } }
            Button("Kill") { Task { await vm.kill(c) } }
        } else {
            Button("Start") { Task { await vm.start(c) } }
        }

        Divider()

        Button("Exec in Terminal") {
            TerminalLauncher.runInTerminal("container exec -it \(c.id) /bin/sh")
        }

        Button("Delete", role: .destructive) {
            Task { await vm.delete(c, force: false) }
        }
    }
}
