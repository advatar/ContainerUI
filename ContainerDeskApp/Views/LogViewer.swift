import SwiftUI
import ContainerDeskCore

struct LogViewer: View {
    let title: String
    let makeStream: () async -> AsyncThrowingStream<OutputLine, Error>

    @StateObject private var vm = LogStreamViewModel()
    @State private var showStderr: Bool = true
    @State private var startTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLines) { line in
                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: vm.lines.count) { _ in
                    // Scroll to bottom
                    if let last = filteredLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            if let err = vm.errorMessage {
                Divider()
                Text(err)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 720, minHeight: 420)
        .navigationTitle(title)
        .onAppear {
            startTask = Task {
                let stream = await makeStream()
                await vm.start(stream: stream)
            }
        }
        .onDisappear {
            startTask?.cancel()
            startTask = nil
            vm.stop()
        }
    }

    private var filteredLines: [LogStreamViewModel.Line] {
        if showStderr { return vm.lines }
        return vm.lines.filter { $0.source == .stdout }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Toggle("Show stderr", isOn: $showStderr)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()

            if vm.isRunning {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Stop") { vm.stop() }
                .disabled(!vm.isRunning)

            Button("Clear") { vm.lines.removeAll() }
        }
        .padding(10)
    }
}
