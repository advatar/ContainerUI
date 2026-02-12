import Foundation

enum TerminalLauncher {
    /// Opens Terminal.app and runs a command in a new window/tab using AppleScript.
    static func runInTerminal(_ command: String) {
        // Escape quotes for AppleScript
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
        } catch {
            // Best-effort helper; ignore in starter.
        }
    }
}
