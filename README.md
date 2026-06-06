# Tinkerble

Tinkerble is a proof-of-concept debug companion system for SwiftUI apps. It lets an iOS app register tweakable values, send logs to a macOS companion app, and receive live value edits back from the Mac during development.

The package is intentionally small and modular:

- `Tinkerble`: iOS-facing library with `@TinkerbleState`, `TinkerLog`, core tweak models, and the RSocket client transport.
- `TinkerbleCompanionCore`: macOS companion store and RSocket server.
- `TinkerbleCompanion`: SwiftUI macOS companion executable with a log console and tweak inspector.
- `Tinkerble Demo`: local iOS demo project that imports the package.

## Current Proof Of Concept

The implemented loop is:

1. The iOS app connects to the macOS companion over an RSocket request-channel.
2. `@TinkerbleState` registers tweakable values.
3. The companion displays uncategorized values first, then grouped categories.
4. Editing a companion control sends an update back to the iOS app.
5. The iOS app applies the update to the registered state.
6. `TinkerLog.print` and `TinkerLog.log` send strings to the companion console.

## Quick Start

From the package root:

```sh
./Scripts/patch-rsocket-checkouts.sh
swift test
```

Then build and run `Tinkerble Demo` in Xcode. The shared demo scheme patches
Xcode's package checkout, builds the macOS companion, and restarts it
automatically for Debug builds before the iOS app target builds. You can opt out
for a build with:

```sh
TINKERBLE_COMPANION_AUTOLAUNCH=0 xcodebuild ...
```

You can also run both apps from the command line:

```sh
./Scripts/run-tinkerble-demo.sh
```

The demo app connects to `127.0.0.1:7777`, which works for iOS Simulator. For a physical device, use the Mac's local network IP address.

`Scripts/package-macos-companion.sh` builds `build/Tinkerble.app`, compiles `Tinkerble.icon` into `Contents/Resources/Assets.car` with Xcode 26 `actool`, writes the user-visible app name as `Tinkerble`, removes legacy `.icns` sidecars, and ad-hoc signs the app for local development. `Scripts/ensure-macos-companion-running.sh` packages that app, opens it as a normal macOS app when needed, restarts it when passed `--restart`, and verifies that `TinkerbleCompanion` is listening on port `7777`. `Scripts/launch-macos-companion.sh` uses the same path with `--restart` for manual relaunches.

## Upstream RSocket Note

Tinkerble depends on `https://github.com/rsocket/rsocket-swift.git`. The current upstream checkout is alpha and needs two local workarounds with Xcode 26.5 on this machine:

- SwiftNIO's Darwin shim hits an SDK visibility issue around `errx`.
- RSocket's `RequestExamples.swift` helper file no longer compiles under the current compiler.

`Scripts/patch-rsocket-checkouts.sh` applies those checkout-only fixes after package resolution. The Tinkerble source does not vendor or rewrite RSocket.

When building the demo project from the command line, pass the patched checkout directory:

```sh
xcodebuild \
  -project "Tinkerble Demo/Tinkerble Demo.xcodeproj" \
  -scheme "Tinkerble Demo" \
  -destination "generic/platform=iOS Simulator" \
  -clonedSourcePackagesDirPath .build \
  build
```

## Adding The Package

In Xcode:

1. Add the local package at the repository root, or add the future remote repository URL.
2. Link the `Tinkerble` product to the iOS app target.
3. Add a Debug-only build pre-action or run script that calls `Scripts/ensure-macos-companion-running.sh` from the package checkout. That hook packages and launches the macOS companion automatically when your app target builds.

In `Package.swift`:

```swift
.package(url: "https://github.com/your-org/Tinkerble.git", branch: "main")
```

Then add:

```swift
.product(name: "Tinkerble", package: "Tinkerble")
```

## Plist Setup

iOS app plist:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Tinkerble connects to the macOS companion app on your local development network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_tinkerble._tcp</string>
</array>
```

The iOS app needs local network permission when connecting to a Mac on the LAN. Bonjour is included for future service discovery; this proof of concept currently uses a fixed host and port.

macOS companion plist, if packaged as a normal app bundle:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Tinkerble listens for debug connections from local iOS development builds.</string>
<key>NSBonjourServices</key>
<array>
    <string>_tinkerble._tcp</string>
</array>
```

The SwiftPM companion executable is not sandboxed by default. If you package and sandbox the companion later, add the appropriate incoming network entitlement too.

## Usage

Start the client in the app:

```swift
import Tinkerble

@main
struct DemoApp: App {
    init() {
        Tinkerble.shared.connect(host: "127.0.0.1", port: 7777)
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Use tweakable state:

```swift
@TinkerbleState(name: "Title")
private var title = "Demo"

@TinkerbleState(category: "Layout", name: "Width", control: .slider(5...400))
private var width = 120

@TinkerbleState(category: "Layout", name: "Opacity", control: .slider(0.0...1.0))
private var opacity = 0.5

@TinkerbleState(category: "Flags", name: "Enabled")
private var isEnabled = true

@TinkerbleState(category: "Palette", name: "Accent Color")
private var accent = Color.blue
```

Swift does not reliably expose the wrapped variable name to the property wrapper, so `name` is required. `category` is optional. Values without a category appear above categorized groups.

Use tweakable observable model state:

```swift
@TinkerbleObservable
@MainActor
final class DemoModel {
    @TinkerbleObservableState(name: "Title")
    var title = "Demo"

    @TinkerbleObservableState(category: "Layout", name: "Width", control: .slider(5...400))
    var width = 120

    @TinkerbleObservableState(category: "Flags", name: "Enabled")
    var isEnabled = true
}
```

`@TinkerbleObservableState` uses the same `name`, `category`, supported value types, enum support, and control APIs as `@TinkerbleState`. It is a macro API for observable model classes; mark the model with `@TinkerbleObservable` instead of Swift's `@Observable` so Tinkerble can generate the Observation registrar and hidden tweak registration storage together.

Basic enums use `TinkerbleEnum`:

```swift
enum DemoMode: String, CaseIterable, TinkerbleEnum {
    case compact
    case expanded
}

@TinkerbleState(category: "Modes", name: "Mode")
private var mode = DemoMode.compact
```

Send logs:

```swift
TinkerLog.print("User tapped Save")
TinkerLog.log("Current opacity: \(opacity)")
```

## Text Controls

Strings use a regular input field by default:

```swift
@TinkerbleState(name: "Title")
private var title = "Demo"
```

You can opt into a text area, or ask Tinkerble to pick one when the registered text is longer than 25 characters:

```swift
@TinkerbleState(name: "Notes", control: .area)
private var notes = "Longer copy"

@TinkerbleState(name: "Subtitle", control: .text(.automatic))
private var subtitle = "Short copy"
```

## Numeric Controls

Integer controls expose integer-only APIs:

```swift
@TinkerbleState(name: "Count", control: TinkerbleControl<Int>.plain)
private var count = 3

@TinkerbleState(name: "Columns", control: .slider(1...6))
private var columns = 3
```

Decimal controls expose decimal configuration:

```swift
@TinkerbleState(name: "Opacity", control: .slider(0.0...1.0, decimalPlaces: 2))
private var opacity = 0.5
```

Defaults:

- `0.0...1.0` defaults to 2 decimal places.
- Larger integer-like decimal ranges such as `0.0...100.0` default to 0 decimal places.
- `Int` controls do not accept `decimalPlaces`.
- Numeric controls are only available for numeric value types.

## Running Both Apps

Automatic mode:

- Build `Tinkerble Demo` in Xcode with the shared scheme.
- The Debug build pre-action builds and restarts the macOS companion.
- The iOS Simulator app then connects to the companion on `127.0.0.1:7777`.

Fixed target mode:

```sh
TINKERBLE_SIMULATOR_UDID=<simulator-udid> TINKERBLE_INTERACTIVE=0 ./Scripts/run-tinkerble-demo.sh
```

Interactive target mode:

```sh
./Scripts/run-tinkerble-demo.sh
```

The script lists available iPhone simulators, starts the macOS companion, builds the iOS demo with the local package, installs it, and launches it.

Fixed mode is better for CI and repeatable local workflows. Interactive mode is better when switching devices frequently.

## Manual Validation Checklist

- Run `swift test`.
- Run `./Scripts/verify-macos-companion-package.sh`.
- Run `./Scripts/launch-macos-companion.sh`.
- Run the iOS demo on Simulator.
- Confirm the companion shows:
  - `Title` above categories.
  - `Enabled` under `Flags`.
  - `Accent Color` under `Palette`.
  - `Card Count` and `Opacity` under `Layout`.
  - `Mood` under `Modes`.
- Edit each companion control and confirm the iOS UI updates.
- Tap `Send Demo Log` in the iOS app and confirm the log appears in the companion console.

## Current Limitations

- Arrays, dictionaries, arbitrary structs, nested models, `ObservableObject`, and `@Published` are intentionally unsupported.
- `@TinkerbleState` is main-actor SwiftUI view state.
- `@TinkerbleObservableState` is main-actor observable model state. Use it inside a `@TinkerbleObservable` class.
- The current connection flow uses a fixed host and port. Bonjour discovery is documented but not implemented.
- Only one active companion session is tracked.
- The companion UI is intentionally basic.
- The RSocket Swift upstream package currently requires checkout workarounds under Xcode 26.5.

## Future Work

- Bonjour discovery and remembered device selection.
- Reconnect and connection health details.
- Multiple client sessions.
- Log categories, levels, grouping, typed values, colors, filtering, search, timestamps, and export.
- Better enum display customization.
- Packaged macOS app bundle with entitlements and plist.
- Production-grade RSocket dependency strategy once upstream Swift compatibility improves.
