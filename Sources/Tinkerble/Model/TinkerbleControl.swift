import Foundation

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
    case stepper(TinkerbleNumericControl)
    case slider(TinkerbleNumericControl)
}

public struct TinkerbleNumericControl: Codable, Equatable, Hashable {
    public var minimum: Double?
    public var maximum: Double?
    public var step: Double
    public var decimalPlaces: Int

    public init(minimum: Double? = nil, maximum: Double? = nil, step: Double = 1, decimalPlaces: Int = 0) {
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.decimalPlaces = decimalPlaces
    }
}

public extension TinkerbleControl where Value: BinaryInteger {
    static func stepper(step: Value = 1) -> Self {
        Self(descriptor: .stepper(.init(step: Double(step), decimalPlaces: 0)))
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
    static func stepper(step: Value = 1, decimalPlaces: Int? = nil) -> Self {
        Self(
            descriptor: .stepper(
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
