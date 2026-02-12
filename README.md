# ContainerDesk Starter (Apple `container` Desktop UI)

This is a **starter codebase** for a macOS SwiftUI app that provides a Docker-Desktop-like experience on top of Apple’s **command-line** container runtime (`container`).

- Apple Container project: [github.com/apple/container](https://github.com/apple/container)

## What you get today

### Implemented (working code paths)
- **System status / start / stop** via `container system …`
- **Containers**: list, start, stop, delete, inspect, logs (follow), exec (opens Terminal)
- **Images**: list, pull, delete, inspect
- **Builder**: status (JSON when available), start/stop (hooks ready)
- **Troubleshoot**: stream `container system logs --follow`

### UI included
- Sidebar navigation (Dashboard, Containers, Images, Builds, Troubleshoot, Settings)
- Containers list with start/stop/logs/inspect/delete
- Images list with pull/delete/inspect
- Streaming log viewer

This starter intentionally focuses on a **small MVP** and a clean architecture so we can iterate quickly.

---

## Requirements

- macOS **26+**
- Apple silicon
- `container` CLI installed and working (try `container system status` in Terminal)

> Note: Some features (like `container system dns create`) require admin privileges. This starter only uses non-privileged commands by default.

---

## How to run

This repo is split into:
- `ContainerDeskCore/` – a Swift Package with the CLI wrapper + models
- `ContainerDeskApp/` – SwiftUI app source files you drop into an Xcode macOS App project

### 1) Verify the core package builds
```bash
cd ContainerDeskCore
swift test
```

### 2) Create an Xcode project for the app
1. Open Xcode → **File → New → Project…**
2. Choose **macOS → App**
3. Name: `ContainerDesk`
4. Interface: **SwiftUI**
5. Language: **Swift**
6. Create the project

### 3) Add `ContainerDeskCore` as a local Swift package
- In Xcode: **File → Add Packages… → Add Local…**
- Select the `ContainerDeskCore` folder
- Add it to the `ContainerDesk` app target

### 4) Add the app sources
- Drag the entire `ContainerDeskApp/` folder into your Xcode project navigator
- When prompted: **Copy items if needed** ✅ and add to the app target

### 5) Wire up the app entrypoint
Open your project’s default `*App.swift` file and set the root view + shared state:

```swift
import SwiftUI
import ContainerDeskCore

@main
struct ContainerDeskApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
```

### 6) Run
Hit **⌘R**.

---

## Roadmap (next steps to build from here)
- Compose “apps” (compose.yaml parser → translate into `container build/run/network`)
- Volumes & Networks pages (feature-detect if the user’s `container` supports them)
- Privileged helper (DNS domain management UI)
- Diagnostics bundle export (zip logs + json snapshots)
- Better “Run” wizard (ports/volumes presets for common images)

---

## License
You can treat this starter as MIT for your own use; replace with your preferred license before publishing.
