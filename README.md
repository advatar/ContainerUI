# ContainerDesk Starter (Docker Desktop-Style UI)

This is a **starter codebase** for a macOS SwiftUI app that provides a Docker-Desktop-like experience on top of the Docker CLI (`docker`), with compatibility fallbacks for Apple `container` commands where practical.

## What you get today

### Implemented (working code paths)
- **System status / start / stop** via `container system …`
- **Containers**: list, start, stop, delete, inspect, logs (follow), exec (opens Terminal)
- **Images**: list, pull, delete, inspect
- **Builder**: status (JSON when available), start/stop (hooks ready)
- **Troubleshoot**: stream daemon-level events/log output
- **Docker CLI parity surface**: run or stream arbitrary Docker commands from an in-app command center, with command catalog coverage for common, management, swarm, and runtime command groups

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
- Docker CLI installed and working (try `docker info` in Terminal)

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
- Compose “apps” (compose.yaml parser → translate into `container build/run/network`)
- Volumes & Networks pages (feature-detect if the user’s `container` supports them)
- Privileged helper (DNS domain management UI)
- Diagnostics bundle export (zip logs + json snapshots)
- Better “Run” wizard (ports/volumes presets for common images)

---

## License
You can treat this starter as MIT for your own use; replace with your preferred license before publishing.
