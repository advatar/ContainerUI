# ContainerDesk Starter (Apple Container + Docker-Compatible API)

This is a **starter codebase** for a macOS SwiftUI app that provides a Docker-Desktop-like experience on top of Apple `container`, while accepting Docker-style commands through a compatibility layer.

## What you get today

### Implemented (working code paths)
- **System status / start / stop** via `container system …`
- **Containers**: list, start, stop, delete, inspect, logs (follow), exec (opens Terminal)
- **Images**: list, pull, delete, inspect
- **Builder**: status (JSON when available), start/stop (hooks ready)
- **Compose**: dedicated Compose page (up/down/ps/pull/build/logs) routed through compatibility commands
- **Troubleshoot**: stream daemon-level events/log output
- **Docker API-compatible command center**: run or stream Docker-style commands (`docker ...`) against the Apple container backend, with command catalog coverage for common, management, compose, swarm, and runtime groups

### UI included
- Sidebar navigation (Dashboard, Containers, Images, Builds, Troubleshoot, Settings)
- Containers list with start/stop/logs/inspect/delete
- Images list with pull/delete/inspect
- Streaming log viewer

This starter intentionally focuses on a **small MVP** and a clean architecture so we can iterate quickly.

---

## Requirements

- macOS **26.2+**
- Apple silicon
- Apple `container` CLI installed and working (try `container system status` in Terminal)

> Note: Some Docker Desktop lifecycle and privileged operations may require elevated permissions.

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

### 2) Generate the app project (Swift 6 + macOS 26.2)
```bash
xcodegen generate
```

This uses the checked-in `project.yml`, which sets:
- Swift language mode: **Swift 6**
- Deployment target: **macOS 26.2**
- Strict concurrency: **Complete**

### 3) Run from Xcode
Open `ContainerDesk.xcodeproj` and hit **⌘R**.

### 4) Run all tests (unit + UI)
```bash
xcodebuild test \
  -project ContainerDesk.xcodeproj \
  -scheme ContainerDesk \
  -destination 'platform=macOS'
```

---

## Roadmap (next steps to build from here)
- Compose model introspection (service-level status cards and structured logs)
- Volumes & Networks pages (feature-detect if the user’s `container` supports them)
- Privileged helper (DNS domain management UI)
- Diagnostics bundle export (zip logs + json snapshots)
- Better “Run” wizard (ports/volumes presets for common images)

---

## License
You can treat this starter as MIT for your own use; replace with your preferred license before publishing.
