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
- `Sources/TinkerbleInstallerCore`: testable installer workflow for mutating consumer Xcode projects.
- `Sources/TinkerbleCLI`: command-line entry point for `tinkerble install`.
- `Tinkerble Demo`: iOS demo app linked against the local package.
- `Scripts`: checkout patching, companion packaging, install verification, and demo run workflow.

## Role

You are a **Senior iOS Engineer**, specializing in SwiftUI, SwiftData, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and App Review guidelines.

## Core Instructions

- Target iOS 26.0 or later - yes, it exists!
- Swift 6.2 or later, using modern Swift concurrency.
- SwiftUI backed up by `@Observable` classes for shared data.
- Do not introduce third-party frameworks without asking first.
- Avoid UIKit unless requested.
- If the project requires secrets, tokens, or API keys, never include them in the repository.

## Task Handling

- When requirements are ambiguous, pause before implementation and ask up to three concise clarifying questions. Prefer concrete choices when possible, and allow free-form clarification when none of the choices fit.
- Do not ask questions when a safe default is obvious. State the assumption and proceed.
- Do not stop at analysis or a progress-only answer. Continue through implementation and verification until the task is complete.
- Definition of complete:
  - Implement the behavior exactly as specified.
  - Add or update tests that verify every acceptance criterion for behavior changes.
  - Run those tests.
  - If a test fails, diagnose and fix the implementation or the test harness.
  - Repeat until all relevant tests pass.
  - If a tool or environment failure blocks one verification path, use an alternate verification path that proves the same behavior.
  - Only final-answer when implementation and verification are both complete.
  - In the final answer, list exactly what passed and what remains unverified, if anything.
- For documentation-only changes, use the narrowest proof that the written guidance is correct, usually `git diff --check -- AGENTS.md` plus targeted content checks. Do not run the full app suite unless the doc change depends on live product behavior.

## Project Structure & Module Organization

- Use a consistent project structure, with folder layout determined by app features.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Keep package, demo, installer, and companion responsibilities separate. Do not move installer or packaging behavior into the runtime library target.
- Keep companion UI resources under their owning target resources, and preserve `Tinkerble.icon` as the source icon document.

## Communication

The iOS app starts an RSocket request-channel to the macOS companion. Registration, snapshot, update, and log messages are JSON-encoded into RSocket payloads. The companion keeps the channel's outbound stream and uses it to send `.update` messages back to the iOS app.

## Tweak Registration

`@TinkerbleState` requires an explicit `name` because Swift property wrappers cannot reliably infer the variable name for UI display. `category` is optional. The tweak ID is `category/name` when a category exists, otherwise `name`.

Supported values are `String`, `Bool`, `Color`, `Int`, `Double`, `Float`, `CGFloat`, and enums conforming to `TinkerbleEnum`.

Numeric control APIs are constrained by value type. Do not add decimal-place arguments to integer controls.

## Logging

`TinkerLog.print` and `TinkerLog.log` write to `OSLog` and forward the string to `Tinkerble.shared`.

Future log work belongs in README TODOs unless the task explicitly asks to implement it.

## Swift Instructions

- Always mark `@Observable` classes with `@MainActor`. Do not use ObservableObject.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.

## Coding Style & Naming Conventions

- Follow Swift 5.9+ defaults: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for members, and mark protocol conformances in dedicated extensions when practical.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- SwiftUI views should always be appended with the name View, like MessageView, ChatView, ReactionView, etc.
- **Every new SwiftUI view MUST include at least one `#Preview`** - this enables rapid iteration and visual verification. Place previews at the bottom of the file showing key states (empty, populated, error, etc.).

- Prefer SwiftUI composition; keep animation logic in dedicated types to preserve readability.
- Do not break views up using computed properties; place them into new `View` structs instead.
- Document non-obvious behaviors with succinct inline comments.
- Add code comments and documentation comments as needed.
- For debugging, use `Logger` channels—never `print`.
- **Logger interpolation requires explicit `self.`** - When logging instance properties in `Logger` calls, Swift's string interpolation capture semantics require explicit `self.` (e.g., `Logger.pagination.debug("Loading \(self.paginationPageSize) more")`). SwiftFormat may flag this as redundant, but `self.` is required for Logger to compile correctly. Do not remove `self.` from Logger interpolations.
- Prefer computed properties over functions whenever an API exposes read-only data and doesn't require inputs. If the body is just returning a stored value, a transformed collection, or any other pure expression, use var `foo: T { ... }` instead of `func foo() -> T`.
  - Keep true functions when the language or protocol demands it (e.g., `RandomNumberGenerator.next()`), or when call-site syntax should communicate "do work" (async operations, heavy computation, throws, mutating behavior). Those cases can't be modeled as nonmutating computed properties anyway.
  - Static helpers follow the same rule: expose cached constants or composed values with static var, not static func.
  - When the API needs a result conditioned on parameters, needs to mutate state, or performs significant work that callers should treat as an action, leave it as a function.
  - In short: If it's parameterless, pure, and conceptually a value, make it a computed property; otherwise stick with a function.
- Do not use computed properties that are simply aliases to properties that are inside another struct, unless it adds semantic value.
- Do not use computed properties with simple logic if it's only being referenced once in the codebase.
- Things like: `.animation(.easeIn) { content` in is a real API. Don't mess with it!

## SwiftUI Instructions

- Never use `ObservableObject` and `@Published`; always use the `@Observable` macro instead.
- Never ever use `GeometryReader`; instead use `onGeometryChange` (or `containerRelativeFrame()`, `visualEffect()`) but only when absolutely necessary.
- Always use `foregroundStyle()` instead of `foregroundColor()`.
- Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Always use the `Tab` API instead of `tabItem()`.
- Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- Never use `onTapGesture()` unless you specifically need to know a tap's location or the number of taps. All other usages should use `Button`.
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead.
- Never use `UIScreen.main.bounds` to read the size of the available space.
- Do not force specific font sizes; prefer using Dynamic Type instead.
- Don't apply the `fontWeight()` modifier unless there is good reason. If you want to make some text bold, always use `bold()` instead of `fontWeight(.bold)`.
- Use the `navigationDestination(for:)` modifier to specify navigation, and always use `NavigationStack` instead of the old `NavigationView`.
- If using an image for a button label, always specify text alongside like this: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- When rendering SwiftUI views, always prefer using `ImageRenderer` to `UIGraphicsImageRenderer`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- When hiding scroll view indicators, use the `.scrollIndicators(.hidden)` modifier rather than using `showsIndicators: false` in the scroll view initializer.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Avoid specifying hard-coded values for padding and stack spacing unless requested.
- Avoid using UIKit colors in SwiftUI code.
- Never use `.easeInOut` for animations; always use `.smooth` instead for more natural motion.
- Do not specify `(extraBounce: 0)` in animations: it is redundant (that's already the default) and is not the desired behavior.
- Do not let views, especially inside scroll views or chat transcripts, jump or pop into new positions. Existing elements must animate continuously from their previous presented position to the next one. Treat abrupt movement, snap-in layout shifts, and content jumping as bugs unless the user explicitly asks for a hard cut.

## SwiftData Instructions

Tinkerble currently does not use SwiftData for its runtime registry, companion store, or installer state. Keep this project live/debug-session oriented unless a task explicitly asks for persistence.

If SwiftData is introduced:

- Keep SwiftData model types focused and clearly named.
- Do not use SwiftData to blur the RSocket transport boundary or persist transient tweak registrations by default.
- If SwiftData is configured to use CloudKit:
  - Never use `@Attribute(.unique)`.
  - Model properties must always either have default values or be marked optional.
  - All relationships must be marked optional.

## Validation

For code changes, run the validation sequence that matches the touched area. The broad package validation is:

```sh
./Scripts/patch-rsocket-checkouts.sh
swift test
./Scripts/verify-macos-companion-package.sh
xcodebuild -project "Tinkerble Demo/Tinkerble Demo.xcodeproj" -scheme "Tinkerble Demo" -destination "generic/platform=iOS Simulator" -clonedSourcePackagesDirPath .build build
```

The patch script is currently needed because upstream `rsocket-swift` and one SwiftNIO C shim do not compile cleanly with Xcode 26.5 without checkout-only workarounds.

All builds should be warning-free. Fix compiler warnings before marking work complete. Common warnings to watch for:

- `var` should be `let` when the variable is never mutated.
- Unnecessary `try` when no throwing functions are called.
- Unnecessary `await` when no async operations occur.
- CFBundleVersion mismatches between app and extension targets.

Run `/opt/homebrew/bin/swiftlint --fix` only on Swift files changed in this work, not the whole repo. Run `swiftformat --config .swiftformat` only on changed Swift files, not the whole repo.

Use focused tests when the change has a narrower proof path:

- `swift test --filter TinkerbleInstallerCoreTests` for installer behavior.
- `swift test --filter TinkerbleComponentPreviewFixtureTests` for All Tinkerble Components fixture changes.
- `swift test --filter TweakInspectorContentTests` for companion inspector rendering/parsing behavior.

## UI Tests

Do not add tests that assert companion UI styling or layout details. Avoid assertions for colors, materials, window chrome, shadows, titlebar presentation, text styling, padding, dimensions, sizing math, control styles, or source snippets that exist only to pin visual implementation. Do not write tests that read source files and assert string containment with `source.contains(...)`, `script.contains(...)`, `project.contains(...)`, or equivalent substring-count checks. Do not assert literal SwiftUI layout/modifier choices such as `ViewThatFits`, `Picker` label text, `.labelsHidden()`, `.fixedSize(...)`, `.pickerStyle(...)`, or `.frame(...)`. Verify UI behavior through user-visible state changes and build or launch the real app instead of freezing visual metrics in tests.

## Do Not Change Carelessly

- Do not remove the transport protocol boundary; the RSocket dependency is alpha and may need replacement or isolation later.
- Do not add support for arrays, dictionaries, structs, nested models, `ObservableObject`, or `@Published` without expanding tests and README limitations.
- Never ever use `ObservableObject` or `@Published`; use `@Observable` and Observation-backed state instead.
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
