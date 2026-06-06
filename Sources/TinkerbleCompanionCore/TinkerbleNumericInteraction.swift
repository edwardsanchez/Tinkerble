import Foundation
import Tinkerble

public enum TinkerbleNumericArrowDirection {
    case increment
    case decrement

    var sign: Double {
        switch self {
        case .increment:
            1
        case .decrement:
            -1
        }
    }
}

public struct TinkerbleNumericKeyboardModifiers: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
}

public enum TinkerbleNumericInteraction {
    public static let dragDistance: Double = 50

    public static func adjustedValue(
        from value: Double,
        direction: TinkerbleNumericArrowDirection,
        modifiers: TinkerbleNumericKeyboardModifiers,
        configuration: TinkerbleNumericControl
    ) -> Double {
        guard let delta = keyboardDelta(for: direction, modifiers: modifiers, decimalPlaces: configuration.decimalPlaces) else {
            return value
        }
        return constrained(value + delta, by: configuration)
    }

    public static func draggedValue(
        from startValue: Double,
        horizontalTranslation: Double,
        configuration: TinkerbleNumericControl
    ) -> Double {
        guard let minimum = configuration.minimum,
              let maximum = configuration.maximum,
              maximum > minimum
        else {
            return startValue
        }

        let clampedTranslation = min(max(horizontalTranslation, -dragDistance), dragDistance)
        let range = maximum - minimum
        let progress = clampedTranslation / (dragDistance * 2)
        return constrained(startValue + range * progress, by: configuration)
    }

    public static func adjustedTextValue(_ value: Double, configuration: TinkerbleNumericControl) -> Double {
        constrained(value, by: configuration)
    }

    private static func keyboardDelta(
        for direction: TinkerbleNumericArrowDirection,
        modifiers: TinkerbleNumericKeyboardModifiers,
        decimalPlaces: Int
    ) -> Double? {
        if modifiers.contains(.option) {
            guard decimalPlaces > 0 else { return nil }
            return direction.sign * 0.1
        }
        if modifiers.contains(.shift) {
            return direction.sign * 10
        }
        return direction.sign
    }

    private static func constrained(_ value: Double, by configuration: TinkerbleNumericControl) -> Double {
        var constrainedValue = value
        if let minimum = configuration.minimum {
            constrainedValue = max(constrainedValue, minimum)
        }
        if let maximum = configuration.maximum {
            constrainedValue = min(constrainedValue, maximum)
        }
        if configuration.decimalPlaces == 0 {
            return constrainedValue.rounded()
        }
        return constrainedValue
    }
}
