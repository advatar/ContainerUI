# Validate

1. Generate project: `xcodegen generate`
2. Build app: `xcodebuild -project ContainerDesk.xcodeproj -scheme ContainerDesk -configuration Debug -derivedDataPath /tmp/ContainerDeskDerived26 build CODE_SIGNING_ALLOWED=NO`
3. Run package tests: `cd ContainerDeskCore && swift test`
4. Open `ContainerDesk.xcodeproj` in Xcode 26.2 and run the `ContainerDesk` scheme.
