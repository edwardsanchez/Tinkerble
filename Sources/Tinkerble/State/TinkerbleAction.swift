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

    init(name: String, screen: String? = nil, category: String?, handler: @escaping () -> Void) {
        self.handler = handler
        registrationToken = Tinkerble.shared.registerAction(
            id: TinkerbleTweak.makeID(screen: screen, category: category, name: name),
            screen: screen,
            category: category,
            name: name,
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

    init(name: String, screen: String? = nil, category: String?, perform: @escaping () -> Void) {
        self.perform = perform
        _box = State(
            wrappedValue: TinkerbleActionBox(
                name: name,
                screen: screen,
                category: category,
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
    func tinkerbleAction(
        _ name: String,
        screen: String? = nil,
        category: String? = nil,
        perform: @escaping () -> Void
    ) -> some View {
#if DEBUG
        return modifier(TinkerbleActionModifier(name: name, screen: screen, category: category, perform: perform))
#else
        _ = name
        _ = screen
        _ = category
        _ = perform
        return self
#endif
    }
}
