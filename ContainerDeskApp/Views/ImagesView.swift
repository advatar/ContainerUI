import SwiftUI
import ContainerDeskCore

struct ImagesView: View {
    @StateObject private var vm: ImagesViewModel
    @State private var searchText: String = ""
    @State private var selectedImageID: String? = nil

    @State private var showingPull: Bool = false
    @State private var pullReference: String = ""

    @State private var showingInspect: Bool = false
    @State private var inspectText: String = ""

    init(engine: ContainerEngine) {
        _vm = StateObject(wrappedValue: ImagesViewModel(engine: engine))
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedImageID) {
                    ForEach(filtered) { img in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(img.reference.isEmpty ? img.id : img.reference)
                                    .font(.headline)
                                if let size = img.size {
                                    Text(size)
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                            Spacer()
                            if let created = img.createdAt {
                                Text(created)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tag(img.id as String?)
                        .contextMenu {
                            Button("Inspect") {
                                selectedImageID = img.id
                                Task {
                                    do {
                                        inspectText = try await vm.inspect(img)
                                        showingInspect = true
                                    } catch {
                                        vm.errorMessage = error.localizedDescription
                                    }
                                }
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                Task { await vm.delete(img, force: false) }
                            }
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
            .frame(minWidth: 320, idealWidth: 420)

            Divider()

            detailPanel
                .frame(minWidth: 380)
        }
        .navigationTitle("Images")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    showingPull = true
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
            }
        }
        .task {
            await vm.refresh()
        }
        .sheet(isPresented: $showingPull) {
            PullImageSheet(reference: $pullReference) { ref in
                Task { await vm.pull(reference: ref) }
            }
            .frame(width: 520)
            .padding()
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

    private var filtered: [ImageSummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.images }
        return vm.images.filter { img in
            img.reference.lowercased().contains(q) || img.id.lowercased().contains(q)
        }
    }

    private var selectedImage: ImageSummary? {
        guard let id = selectedImageID else { return nil }
        return vm.images.first(where: { $0.id == id })
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let img = selectedImage {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(img.reference.isEmpty ? "Image" : img.reference)
                        .font(.title.bold())

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            keyValue("ID", img.id)
                            if !img.repository.isEmpty { keyValue("Repo", img.repository) }
                            if !img.tag.isEmpty { keyValue("Tag", img.tag) }
                            if let size = img.size { keyValue("Size", size) }
                            if let created = img.createdAt { keyValue("Created", created) }
                        }
                        .textSelection(.enabled)
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }

                    HStack(spacing: 10) {
                        Button("Inspect") {
                            Task {
                                do {
                                    inspectText = try await vm.inspect(img)
                                    showingInspect = true
                                } catch {
                                    vm.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        Spacer()
                        Button("Delete", role: .destructive) {
                            Task { await vm.delete(img, force: false) }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
        } else {
            ContentUnavailableView("Select an image", systemImage: "square.stack.3d.up", description: Text("Choose an image from the list to see details."))
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
}

private struct PullImageSheet: View {
    @Binding var reference: String
    let onPull: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pull Image")
                .font(.headline)

            TextField("e.g. nginx:latest", text: $reference)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Pull") {
                    let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !ref.isEmpty else { return }
                    onPull(ref)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}
