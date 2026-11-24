import Foundation
import Observation
import SwiftUI

#if DEBUG
@Observable
@MainActor
final class TinkerbleActionBox {
    @ObservationIgnored
    var handler: () -> Void

    @ObservationIgnored
    private var registrationToken: TinkerbleRegistrationToken?

    init(
        name: String,
        screen: String? = nil,
        category: String?,
        declarationLocation: TinkerbleSourceLocation? = nil,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        registrationToken = Tinkerble.shared.registerAction(
            id: TinkerbleTweak.makeID(screen: screen, category: category, name: name),
            screen: screen,
            category: category,
            name: name,
            declarationLocation: declarationLocation,
            perform: { [weak self] in
                self?.handler()
            }
        )
    }

    deinit {
        if let registrationToken {
            Task { @MainActor in
                Tinkerble.shared.unregister(registrationToken)
            }
        }
    }
}

private struct TinkerbleActionModifier: ViewModifier {
    @State private var box: TinkerbleActionBox
    private let perform: () -> Void

    init(
        name: String,
        screen: String? = nil,
        category: String?,
        declarationLocation: TinkerbleSourceLocation,
        perform: @escaping () -> Void
    ) {
        self.perform = perform
        _box = State(
            wrappedValue: TinkerbleActionBox(
                name: name,
                screen: screen,
                category: category,
                declarationLocation: declarationLocation,
                handler: perform
            )
        )
    }

    func body(content: Content) -> some View {
        box.handler = perform
        return content
    }
}
#endif

public extension View {
#if DEBUG
    /// Registers a companion button that runs `perform`.
    ///
    /// The companion orders the action by where this modifier is called, so an action
    /// called in `body` lands after the properties declared above it in the same file.
    /// `filePath`, `line` and `column` capture that call site; leave them defaulted.
    /// They exist only in DEBUG builds, so release builds embed no call-site metadata.
    func tinkerbleAction(
        _ name: String,
        screen: String? = nil,
        category: String? = nil,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column,
        perform: @escaping () -> Void
    ) -> some View {
        modifier(
            TinkerbleActionModifier(
                name: name,
                screen: screen,
                category: category,
                declarationLocation: .init(filePath: "\(filePath)", line: Int(line), column: Int(column)),
                perform: perform
            )
        )
    }
#else
    /// Registers a companion button that runs `perform`. A no-op outside DEBUG builds.
    func tinkerbleAction(
        _ name: String,
        screen: String? = nil,
        category: String? = nil,
        perform: @escaping () -> Void
    ) -> some View {
        _ = name
        _ = screen
        _ = category
        _ = perform
        return self
    }
#endif
}
