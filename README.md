[![Watch the Tinkerble demo](Documentation/Assets/tinkerble-demo-video-poster.png)](https://youtu.be/QhzZxTYLpzw)

# Tinkerble
Tinkerble is debug companion system for SwiftUI apps on Apple platforms. It lets an app register tweakable values and actions, send logs to a macOS companion app, receive live value edits back from the Mac, and trigger app-side commands during development.
The package is intentionally small and modular:
- `Tinkerble`: app-facing library with `@TinkerbleState`, `.tinkerbleAction`, `@TinkerbleObservableState`, `@TinkerbleAction`, `TinkerLog`, core tweak models, and the RSocket client transport.
- `TinkerbleCompanionCore`: macOS companion store and RSocket server.
- `TinkerbleCompanion`: SwiftUI macOS companion executable with a log console and tweak inspector.
- `Tinkerble Demo`: local iOS demo project that imports the package.

## Implementation Loop
1. The app connects to the macOS companion over an RSocket request-channel.
2. `@TinkerbleState`, `.tinkerbleAction`, `@TinkerbleObservableState`, and `@TinkerbleAction` register tweakable values and actions.
3. The companion displays tweaks by screen, with uncategorized values first, then grouped categories.
4. Editing a companion control sends an update back to the app.
5. Tapping an action button sends a trigger back to the app.
6. The app applies value updates or runs the registered action closure.
7. `TinkerLog.print` and `TinkerLog.log` send strings to the companion console.

## Platform Support
Tinkerble's client library is designed to be platform-agnostic across Apple SwiftUI apps. The same `Tinkerble` product should work from iOS, macOS, tvOS, watchOS, and visionOS apps as long as the app can import SwiftUI and Observation and open a TCP connection to the Mac running the companion.
The current repository has first-class demo coverage for iOS Simulator and a macOS companion app, and the package currently declares iOS and macOS minimums.
There are not yet tvOS, watchOS, or visionOS demo projects in this repo, so those platforms should be treated as expected-compatible rather than separately demo-verified.

## Install Tinkerble In Your App
Install the `tinkerble` command:
```sh
curl -fsSL https://raw.githubusercontent.com/edwardsanchez/Tinkerble/main/install.sh | sh
```

Then run it from your app repository:
```sh
cd /path/to/MyApp
tinkerble install
```

The installer adds the Tinkerble Swift package, links the `Tinkerble` product to your selected app target, adds the local-network plist setup, and adds a Debug-only build phase that launches the macOS companion from the resolved package checkout. If more than one Debug scheme builds the selected target, the installer asks which Debug schemes should get Tinkerble's package-patch pre-action. Release and TestFlight-style schemes are not offered for that pre-action.
Xcode still owns normal package updates after installation: update Tinkerble through Xcode's package UI and the build phase will continue to use the scripts from the resolved package version.
Use explicit flags when scripting the install or working in a repo with multiple projects or app targets:
```sh
tinkerble install --project MyApp.xcodeproj --target MyApp
tinkerble install --project MyApp.xcodeproj --target MyApp --target DemoApp
tinkerble install --project MyApp.xcodeproj --target MyApp --scheme "MyApp Debug"
tinkerble install --project MyApp.xcodeproj --target MyApp --dry-run
```

Repeat `--scheme` to install the package-patch pre-action into multiple Debug schemes.

## Quick Start For This Package

From the package root:
```sh
./Scripts/patch-rsocket-checkouts.sh
swift test
```

Then build and run `Tinkerble Demo` in Xcode. The shared demo scheme patches Xcode's package checkout, builds the macOS companion, and restarts it automatically for Debug builds before the app target builds. You can opt out for a build with:
```sh
TINKERBLE_COMPANION_AUTOLAUNCH=0 xcodebuild ...
```

You can also run both apps from the command line:
```sh
./Scripts/run-tinkerble-demo.sh
```

The demo app connects to `127.0.0.1:7777`, which works for Simulator-based clients running on the Mac. For a physical device, use the Mac's local network IP address.

`Scripts/package-macos-companion.sh` builds `build/Tinkerble.app`, compiles `Tinkerble.icon` into `Contents/Resources/Assets.car` with Xcode 26 `actool`, writes the user-visible app name as `Tinkerble`, removes legacy `.icns` sidecars, and ad-hoc signs the app for local development. `Scripts/ensure-macos-companion-running.sh` packages that app, opens it as a normal macOS app when needed, restarts it when passed `--restart`, and verifies that `TinkerbleCompanion` is listening on port `7777`. `Scripts/launch-macos-companion.sh` uses the same path with `--restart` for manual relaunches.

## Upstream RSocket Note
Tinkerble depends on `https://github.com/edwardsanchez/rsocket-swift.git` branch `tinkerble-xcode26-main`, a minimal fork of upstream RSocket with the stale `RequestExamples.swift` helper source disabled. The current upstream dependency stack still needs one checkout workaround with Xcode 26.5 on this machine:
- SwiftNIO's Darwin shim hits an SDK visibility issue around `errx`.

`Scripts/patch-rsocket-checkouts.sh` applies that checkout-only fix after package resolution. The Tinkerble source does not vendor RSocket.
When building the demo project from the command line, pass the patched checkout directory:

```sh
xcodebuild \
  -project "Tinkerble Demo/Tinkerble Demo.xcodeproj" \
  -scheme "Tinkerble Demo" \
  -destination "generic/platform=iOS Simulator" \
  -clonedSourcePackagesDirPath .build \
  build
```

## Manual Package Setup
In Xcode:
1. Add the local package at the repository root, or add the remote repository URL.
2. Link the `Tinkerble` product to the app target.
3. Add a Debug-only build pre-action or run script that calls `Scripts/ensure-macos-companion-running.sh` from the package checkout. That hook packages and launches the macOS companion automatically when your app target builds.

In `Package.swift`:
```swift
.package(url: "https://github.com/edwardsanchez/Tinkerble.git", branch: "main")
```

Then add:
```swift
.product(name: "Tinkerble", package: "Tinkerble")
```

## Plist Setup
App plist:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Tinkerble connects to the macOS companion app on your local development network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_tinkerble._tcp</string>
</array>
```

An app needs local network permission when connecting to a Mac on the LAN.
Bonjour is included for future service discovery; this proof of concept currently uses a fixed host and port.
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

Use `@TinkerbleState` for SwiftUI view-local tweakable state:
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

Swift does not reliably expose the wrapped variable name to the property wrapper, so `name` is required. `screen` and `category` are optional. Omit `screen` for the default screen, and use it when one app view registers a distinct group of controls. Values without a category appear above categorized groups.

Use `@TinkerbleObservableState` for normal stored properties inside `@Observable` classes. Add `@TinkerbleObservable` to the class and keep using normal Observation and `@Bindable` bindings from SwiftUI:

```swift
@TinkerbleObservable
@Observable
@MainActor
final class Model {
    @TinkerbleObservableState(category: "Observable", name: "Badge Text", screen: "Basic")
    var badgeText = "Observable Model"

    @TinkerbleObservableState(category: "Observable", name: "Badge Count", screen: "Basic", control: TinkerbleControl<Int>.plain)
    var badgeCount = 2
}

struct EditorView: View {
    @Bindable var model: Model

    var body: some View {
        TextField("Badge Text", text: $model.badgeText)
    }
}
```

`@TinkerbleObservableState` supports the same `name`, `category`, `screen`, and `control` arguments as `@TinkerbleState`, but it does not create projected SwiftUI bindings. The property remains a normal Observation-tracked property, so SwiftUI bindings come from `@Bindable`.

Use `.tinkerbleAction` to expose a companion button from a SwiftUI view:
```swift
struct FanDeckView: View {
    @State private var isExpanded = false

    var body: some View {
        DeckView(isExpanded: isExpanded)
            .tinkerbleAction("Fan Out / Collapse", screen: "Fan Deck", category: "Animation") {
                isExpanded.toggle()
            }
    }
}
```

Use `@TinkerbleAction` and `@TinkerbleActions` for zero-parameter methods on `@Observable` classes. Call the generated `activateTinkerbleActions()` once from `init`:
```swift
@TinkerbleActions
@Observable
@MainActor
final class Model {
    var actionCount = 0

    init() {
        activateTinkerbleActions()
    }

    @TinkerbleAction(name: "Increment Action Count", screen: "Basic", category: "Observable")
    func incrementActionCount() {
        actionCount += 1
    }
}
```

`@TinkerbleAction` methods must not take parameters. They support optional `name`, `screen`, and `category` arguments. If `name` is omitted, Tinkerble uses the method name.

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
- The Simulator app then connects to the companion on `127.0.0.1:7777`.

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
  - `Fan Out / Collapse` button under `Animation` on the `Fan Deck` screen.
  - `Increment Action Count` under `Observable` on the `Basic` screen.
- Edit each companion control and confirm the app UI updates.
- Tap each companion action button and confirm the app UI updates.

## Current Limitations
- Arrays, dictionaries, arbitrary structs, nested models, `ObservableObject`, and `@Published` are intentionally unsupported.
- `@TinkerbleState` is main-actor SwiftUI view state.
- `@TinkerbleObservableState` is for default-initialized `@Observable` classes marked with `@TinkerbleObservable`. Classes with explicit custom initializers are not supported yet.
- The app-facing package intentionally has a compile-time SwiftSyntax macro dependency for `@TinkerbleObservable` and `@TinkerbleActions`.
- The current connection flow uses a fixed host and port. Bonjour discovery is documented but not implemented.
- Only one active companion session is tracked.
- The companion UI is intentionally basic.
- The RSocket Swift upstream package currently requires checkout workarounds under Xcode 26.5.

## License
Tinkerble is available under the Apache License 2.0. See `LICENSE` for details.

## Future Work
- Bonjour discovery and remembered device selection.
- Reconnect and connection health details.
- Multiple client sessions.
- Log categories, levels, grouping, typed values, colors, filtering, search, timestamps, and export.
- Better enum display customization.
- Packaged macOS app bundle with entitlements and plist.
- Production-grade RSocket dependency strategy once upstream Swift compatibility improves.
