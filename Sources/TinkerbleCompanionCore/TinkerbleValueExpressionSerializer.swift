import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import Tinkerble

public struct TinkerbleValueExpressionSerializer: Sendable {
    public init() {}

    public func expression(
        for tweak: TinkerbleTweak,
        anchor: TinkerbleSourceAnchor,
        currentInitializer: String
    ) throws -> String {
        guard let sourceValueType = tweak.sourceValueType else {
            throw TinkerbleSourceEditIssue(tweak: tweak, reason: .unsupportedValue(
                "Tinkerble did not receive the concrete Swift type for this value. Rebuild and try again."
            ))
        }

        switch (sourceValueType, tweak.value) {
        case let (.string, .string(value)):
            return StringLiteralExprSyntax(content: value).description
        case let (.bool, .bool(value)):
            return value ? "true" : "false"
        case let (.color, .color(value)):
            return "Color(.sRGB, red: \(doubleExpression(value.red)), green: \(doubleExpression(value.green)), blue: \(doubleExpression(value.blue)), opacity: \(doubleExpression(value.alpha)))"
        case let (.int, .number(value)):
            guard let integer = Int(exactly: value) else {
                throw unsupported(tweak, "The value \(value) cannot be represented exactly as an Int in source code.")
            }
            return String(integer)
        case let (.double, .number(value)):
            return doubleExpression(value, decimalPlaces: numericDecimalPlaces(in: tweak.control))
        case let (.float, .number(value)):
            return typedFloatingExpression(
                typeName: "Float",
                value: value,
                decimalPlaces: numericDecimalPlaces(in: tweak.control)
            )
        case let (.cgFloat, .number(value)):
            return typedFloatingExpression(
                typeName: "CGFloat",
                value: value,
                decimalPlaces: numericDecimalPlaces(in: tweak.control)
            )
        case let (.angle, .number(value)):
            return angleExpression(radians: value, control: tweak.control)
        case let (.date, .date(value)):
            return "Date(timeIntervalSinceReferenceDate: \(doubleExpression(value.timeIntervalSinceReferenceDate)))"
        case let (.enumeration(typeName), .enumCase(id)):
            return enumExpression(
                id: id,
                typeName: typeName,
                originalInitializer: anchor.initializerExpression,
                currentInitializer: currentInitializer
            )
        default:
            throw unsupported(
                tweak,
                "The live value does not match its original Swift type, so Tinkerble cannot write it safely."
            )
        }
    }

    private func angleExpression(radians: Double, control: TinkerbleControlDescriptor) -> String {
        let unit: TinkerbleAngleUnit
        switch control {
        case let .plain(configuration), let .slider(configuration):
            unit = configuration.angleUnit ?? .radians
        case .automatic, .text, .date:
            unit = .radians
        }

        switch unit {
        case .degrees:
            let degrees = radians * 180 / .pi
            return "Angle.degrees(\(doubleExpression(degrees, decimalPlaces: numericDecimalPlaces(in: control))))"
        case .radians:
            return "Angle.radians(\(doubleExpression(radians, decimalPlaces: numericDecimalPlaces(in: control))))"
        }
    }

    private func enumExpression(
        id: String,
        typeName: String,
        originalInitializer: String,
        currentInitializer _: String
    ) -> String {
        let encodedID = StringLiteralExprSyntax(content: id).description
        return "\(typeName).tinkerbleCase(for: \(encodedID)) ?? (\(originalInitializer))"
    }

    private func typedFloatingExpression(typeName: String, value: Double, decimalPlaces: Int?) -> String {
        if value.isNaN {
            return "\(typeName).nan"
        }
        if value == .infinity {
            return "\(typeName).infinity"
        }
        if value == -.infinity {
            return "-\(typeName).infinity"
        }
        return "\(typeName)(\(String(sourceValue(value, decimalPlaces: decimalPlaces))))"
    }

    private func doubleExpression(_ value: Double, decimalPlaces: Int? = nil) -> String {
        if value.isNaN {
            return "Double.nan"
        }
        if value == .infinity {
            return "Double.infinity"
        }
        if value == -.infinity {
            return "-Double.infinity"
        }
        return String(sourceValue(value, decimalPlaces: decimalPlaces))
    }

    private func sourceValue(_ value: Double, decimalPlaces: Int?) -> Double {
        guard let decimalPlaces else { return value }
        return TinkerbleNumericInteraction.normalizedValue(value, decimalPlaces: decimalPlaces)
    }

    private func numericDecimalPlaces(in control: TinkerbleControlDescriptor) -> Int? {
        switch control {
        case let .plain(configuration), let .slider(configuration):
            configuration.decimalPlaces
        case .automatic, .text, .date:
            nil
        }
    }

    private func unsupported(_ tweak: TinkerbleTweak, _ message: String) -> TinkerbleSourceEditIssue {
        TinkerbleSourceEditIssue(tweak: tweak, reason: .unsupportedValue(message))
    }
}
