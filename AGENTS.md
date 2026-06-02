# Tinkerble Agent Notes

Tinkerble is a proof-of-concept debug companion system. The iOS-side package registers tweakable SwiftUI state and logs; the macOS companion receives those values over RSocket, renders controls, and sends edits back to the iOS app.

## Architecture

- `Sources/Tinkerble/Model`: Codable tweak values, enum options, colors, and control descriptors.
- `Sources/Tinkerble/State/TinkerbleState.swift`: `@TinkerbleState` property wrapper and registration box.
- `Sources/Tinkerble/Tinkerble.swift`: main client registry, transport binding, remote update application, and snapshot publishing.
- `Sources/Tinkerble/Transport`: wire messages, RSocket payload codec, and RSocket client transport.
- `Sources/Tinkerble/Logging/TinkerLog.swift`: simple logging API that forwards strings to the companion.
- `Sources/TinkerbleCompanionCore`: companion store and RSocket TCP server.
- `Sources/TinkerbleCompanion`: macOS SwiftUI split-view app.
- `Tinkerble Demo`: iOS demo app linked against the local package.
- `Scripts`: checkout patching and demo run workflow.

## Communication

The iOS app starts an RSocket request-channel to the macOS companion. Registration, snapshot, update, and log messages are JSON-encoded into RSocket payloads. The companion keeps the channel's outbound stream and uses it to send `.update` messages back to the iOS app.

## Tweak Registration

`@TinkerbleState` requires an explicit `name` because Swift property wrappers cannot reliably infer the variable name for UI display. `category` is optional. The tweak ID is `category/name` when a category exists, otherwise `name`.

Supported values are `String`, `Bool`, `Color`, `Int`, `Double`, `Float`, `CGFloat`, and enums conforming to `TinkerbleEnum`.

Numeric control APIs are constrained by value type. Do not add decimal-place arguments to integer controls.

## Logging

`TinkerLog.print` and `TinkerLog.log` write to `OSLog` and forward the string to `Tinkerble.shared`.

Future log work belongs in README TODOs unless the task explicitly asks to implement it.

## Validation

Run:

```sh
./Scripts/patch-rsocket-checkouts.sh
swift test
./Scripts/verify-macos-companion-package.sh
xcodebuild -project "Tinkerble Demo/Tinkerble Demo.xcodeproj" -scheme "Tinkerble Demo" -destination "generic/platform=iOS Simulator" -clonedSourcePackagesDirPath .build build
```

The patch script is currently needed because upstream `rsocket-swift` and one SwiftNIO C shim do not compile cleanly with Xcode 26.5 without checkout-only workarounds.

## Do Not Change Carelessly

- Do not remove the transport protocol boundary; the RSocket dependency is alpha and may need replacement or isolation later.
- Do not add support for arrays, dictionaries, structs, nested models, `ObservableObject`, or `@Published` without expanding tests and README limitations.
- Do not make the demo depend on unpatched DerivedData package checkouts for verification; use `-clonedSourcePackagesDirPath .build`.
- Do not replace explicit display names with guessed property names.
- Do not broaden the companion UI into a design system unless requested.
- Do not replace `Tinkerble.icon` with generated PNGs or `.icns` files. Xcode 26 should compile the `.icon` document into `Assets.car`, and the app plist should reference it with `CFBundleIconName`.

## Known Limitations

- Fixed host/port connection.
- One active session.
- Basic companion controls.
- No Bonjour discovery implementation yet.
- RSocket upstream compatibility requires local checkout patching under the current toolchain.
