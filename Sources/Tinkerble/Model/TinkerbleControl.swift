import Foundation
import SwiftUI

public struct TinkerbleControl<Value> {
    internal let descriptor: TinkerbleControlDescriptor

    public static var automatic: Self {
        Self(descriptor: .automatic)
    }

    internal init(descriptor: TinkerbleControlDescriptor) {
        self.descriptor = descriptor
    }
}

public enum TinkerbleControlDescriptor: Codable, Equatable, Hashable {
    case automatic
    case text(TinkerbleTextControl)
    case plain(TinkerbleNumericControl)
    case slider(TinkerbleNumericControl)
    case date(TinkerbleDateControl)
}

public enum TinkerbleTextControlStyle: String, Codable, Equatable, Hashable {
    case automatic
    case field
    case area
}

public struct TinkerbleTextControl: Codable, Equatable, Hashable {
    public static let automaticAreaThreshold = 25

    public var style: TinkerbleTextControlStyle

    public init(style: TinkerbleTextControlStyle) {
        self.style = style
    }

    public func resolvedStyle(for value: String) -> TinkerbleTextControlStyle {
        switch style {
        case .automatic:
            value.count > Self.automaticAreaThreshold ? .area : .field
        case .field, .area:
            style
        }
    }
}

public struct TinkerbleNumericControl: Codable, Equatable, Hashable {
    public var minimum: Double?
    public var maximum: Double?
    public var step: Double
    public var decimalPlaces: Int
    public var angleUnit: TinkerbleAngleUnit?

    public init(
        minimum: Double? = nil,
        maximum: Double? = nil,
        step: Double = 1,
        decimalPlaces: Int = 0,
        angleUnit: TinkerbleAngleUnit? = nil
    ) {
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.decimalPlaces = decimalPlaces
        self.angleUnit = angleUnit
    }
}

public enum TinkerbleAngleUnit: String, Codable, Equatable, Hashable {
    case degrees
    case radians

    public var displayName: String {
        switch self {
        case .degrees:
            "degrees"
        case .radians:
            "radians"
        }
    }

    public func displayValue(from angle: Angle) -> Double {
        switch self {
        case .degrees:
            angle.degrees
        case .radians:
            angle.radians
        }
    }

    public func displayValue(fromStoredRadians radians: Double) -> Double {
        displayValue(from: .radians(radians))
    }

    public func storedRadians(fromDisplayValue value: Double) -> Double {
        switch self {
        case .degrees:
            Angle.degrees(value).radians
        case .radians:
            value
        }
    }
}

public enum TinkerbleDateControlComponents: String, Codable, Equatable, Hashable {
    case date
    case dateAndTime
    case time
}

public struct TinkerbleDateControl: Codable, Equatable, Hashable {
    public var components: TinkerbleDateControlComponents

    public init(components: TinkerbleDateControlComponents = .dateAndTime) {
        self.components = components
    }
}

public extension TinkerbleControl where Value == String {
    static var field: Self {
        Self(descriptor: .text(.init(style: .field)))
    }

    static var area: Self {
        Self(descriptor: .text(.init(style: .area)))
    }

    static func text(_ style: TinkerbleTextControlStyle) -> Self {
        Self(descriptor: .text(.init(style: style)))
    }
}

public extension TinkerbleControl where Value == Angle {
    static var plain: Self {
        plain()
    }

    static func plain(
        unit: TinkerbleAngleUnit = .degrees,
        step: Angle? = nil,
        decimalPlaces: Int? = nil
    ) -> Self {
        Self(
            descriptor: .plain(
                .init(
                    step: step.map(unit.displayValue(from:)) ?? defaultStep(for: unit),
                    decimalPlaces: decimalPlaces ?? defaultDecimalPlaces(for: unit),
                    angleUnit: unit
                )
            )
        )
    }

    static func slider(
        _ range: ClosedRange<Angle>,
        unit: TinkerbleAngleUnit = .degrees,
        step: Angle? = nil,
        decimalPlaces: Int? = nil
    ) -> Self {
        let lowerBound = unit.displayValue(from: range.lowerBound)
        let upperBound = unit.displayValue(from: range.upperBound)
        return Self(
            descriptor: .slider(
                .init(
                    minimum: lowerBound,
                    maximum: upperBound,
                    step: step.map(unit.displayValue(from:)) ?? inferredAngleStep(for: lowerBound...upperBound, unit: unit),
                    decimalPlaces: decimalPlaces ?? inferredAngleDecimalPlaces(for: lowerBound...upperBound, unit: unit),
                    angleUnit: unit
                )
            )
        )
    }

    private static func defaultStep(for unit: TinkerbleAngleUnit) -> Double {
        switch unit {
        case .degrees:
            1
        case .radians:
            0.01
        }
    }

    private static func defaultDecimalPlaces(for unit: TinkerbleAngleUnit) -> Int {
        switch unit {
        case .degrees:
            0
        case .radians:
            2
        }
    }

    private static func inferredAngleStep(for range: ClosedRange<Double>, unit: TinkerbleAngleUnit) -> Double {
        inferredAngleDecimalPlaces(for: range, unit: unit) == 0 ? 1 : 0.01
    }

    private static func inferredAngleDecimalPlaces(for range: ClosedRange<Double>, unit: TinkerbleAngleUnit) -> Int {
        switch unit {
        case .degrees:
            if range.lowerBound.rounded() == range.lowerBound,
               range.upperBound.rounded() == range.upperBound {
                return 0
            }
            return 2
        case .radians:
            return 2
        }
    }
}

public extension TinkerbleControl where Value == Date {
    static var date: Self {
        Self(descriptor: .date(.init(components: .date)))
    }

    static var dateAndTime: Self {
        Self(descriptor: .date(.init(components: .dateAndTime)))
    }

    static var time: Self {
        Self(descriptor: .date(.init(components: .time)))
    }

    static func datePicker(_ components: TinkerbleDateControlComponents) -> Self {
        Self(descriptor: .date(.init(components: components)))
    }
}

public extension TinkerbleControl where Value: BinaryInteger {
    static var plain: Self {
        Self(descriptor: .plain(.init(decimalPlaces: 0)))
    }

    static func plain(step: Value) -> Self {
        Self(descriptor: .plain(.init(step: Double(step), decimalPlaces: 0)))
    }

    static func slider(_ range: ClosedRange<Value>, step: Value = 1) -> Self {
        Self(
            descriptor: .slider(
                .init(
                    minimum: Double(range.lowerBound),
                    maximum: Double(range.upperBound),
                    step: Double(step),
                    decimalPlaces: 0
                )
            )
        )
    }
}

public extension TinkerbleControl where Value: BinaryFloatingPoint {
    static var plain: Self {
        Self(descriptor: .plain(.init(decimalPlaces: inferredDecimalPlaces(for: nil))))
    }

    static func plain(step: Value = 1, decimalPlaces: Int? = nil) -> Self {
        Self(
            descriptor: .plain(
                .init(
                    step: Double(step),
                    decimalPlaces: decimalPlaces ?? inferredDecimalPlaces(for: nil)
                )
            )
        )
    }

    static func slider(_ range: ClosedRange<Value>, step: Value? = nil, decimalPlaces: Int? = nil) -> Self {
        let lowerBound = Double(range.lowerBound)
        let upperBound = Double(range.upperBound)
        return Self(
            descriptor: .slider(
                .init(
                    minimum: lowerBound,
                    maximum: upperBound,
                    step: step.map(Double.init) ?? inferredStep(for: lowerBound...upperBound),
                    decimalPlaces: decimalPlaces ?? inferredDecimalPlaces(for: lowerBound...upperBound)
                )
            )
        )
    }

    private static func inferredStep(for range: ClosedRange<Double>) -> Double {
        inferredDecimalPlaces(for: range) == 0 ? 1 : 0.01
    }

    private static func inferredDecimalPlaces(for range: ClosedRange<Double>?) -> Int {
        guard let range else { return 2 }
        if range.lowerBound == 0, range.upperBound == 1 {
            return 2
        }
        if range.lowerBound.rounded() == range.lowerBound,
           range.upperBound.rounded() == range.upperBound,
           abs(range.upperBound - range.lowerBound) >= 10 {
            return 0
        }
        return 2
    }
}
