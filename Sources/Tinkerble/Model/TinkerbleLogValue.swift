import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TinkerbleLogValue: Codable, Equatable, Hashable {
    public static let defaultDecimalPlaces = 1
    public static let maximumDecimalPlaces = 9

    case string(String)
    case int(Int)
    case double(Double)
    case components([TinkerbleLogNumericComponent])
    case color(TinkerbleColor)

    public var displayValue: String {
        displayValue(decimalPlaces: Self.defaultDecimalPlaces)
    }

    public func displayValue(decimalPlaces: Int) -> String {
        switch self {
        case let .string(value):
            return value
        case let .int(value):
            return String(value)
        case let .double(value):
            return Self.truncatedDecimalString(value, decimalPlaces: decimalPlaces)
        case let .components(components):
            return components.map { component in
                "\(component.label) \(component.displayValue(decimalPlaces: decimalPlaces))"
            }
            .joined(separator: ", ")
        case let .color(value):
            return value.logDisplayValue
        }
    }

    fileprivate static func labeledComponents(_ components: [(String, Double)]) -> TinkerbleLogValue {
        .components(
            components.map { label, value in
                TinkerbleLogNumericComponent(label: label, value: value)
            }
        )
    }

    fileprivate static func truncatedDecimalString(_ value: Double, decimalPlaces: Int) -> String {
        guard value.isFinite else { return String(value) }

        let decimalPlaces = min(max(0, decimalPlaces), maximumDecimalPlaces)
        let sign = value < 0 ? "-" : ""
        let scale = pow(10, Double(decimalPlaces))
        let scaledMagnitude = (abs(value) * scale).rounded(.down)

        guard scaledMagnitude <= Double(Int.max) else {
            return String(value)
        }

        let scaledInteger = Int(scaledMagnitude)
        let scaleInteger = Int(scale)
        let whole = scaledInteger / scaleInteger

        guard decimalPlaces > 0 else {
            return "\(sign)\(whole)"
        }

        let fraction = String(scaledInteger % scaleInteger)
            .leftPaddedWithZeros(toLength: decimalPlaces)
        return "\(sign)\(whole).\(fraction)"
    }
}

public struct TinkerbleLogNumericComponent: Codable, Equatable, Hashable, Identifiable {
    public var id: String { label }
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.value = value
    }

    public var isNegative: Bool {
        value < 0
    }

    public func displayValue(decimalPlaces: Int) -> String {
        TinkerbleLogValue.truncatedDecimalString(value, decimalPlaces: decimalPlaces)
    }

    public func magnitudeDisplayValue(decimalPlaces: Int) -> String {
        TinkerbleLogValue.truncatedDecimalString(abs(value), decimalPlaces: decimalPlaces)
    }
}

public protocol TinkerbleLogValueConvertible {
    var tinkerbleLogValue: TinkerbleLogValue { get }
    func tinkerbleLogValue(decimalPlaces: Int) -> TinkerbleLogValue
}

public extension TinkerbleLogValueConvertible {
    func tinkerbleLogValue(decimalPlaces: Int) -> TinkerbleLogValue {
        tinkerbleLogValue
    }
}

extension String: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .string(self) }
}

extension Int: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .int(self) }
}

extension Double: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .double(self) }
}

extension Float: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .double(Double(self)) }
}

extension CGFloat: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .double(Double(self)) }
}

extension Color: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .color(TinkerbleColor(self)) }
}

extension TinkerbleColor: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .color(self) }
}

extension CGPoint: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue {
        .labeledComponents([
            ("x", Double(x)),
            ("y", Double(y))
        ])
    }
}

extension CGSize: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue {
        .labeledComponents([
            ("width", Double(width)),
            ("height", Double(height))
        ])
    }
}

extension CGRect: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue {
        .labeledComponents([
            ("x", Double(origin.x)),
            ("y", Double(origin.y)),
            ("width", Double(size.width)),
            ("height", Double(size.height))
        ])
    }
}

extension CGVector: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue {
        .labeledComponents([
            ("dx", Double(dx)),
            ("dy", Double(dy))
        ])
    }
}

extension CGAffineTransform: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue {
        .labeledComponents([
            ("a", a),
            ("b", b),
            ("c", c),
            ("d", d),
            ("tx", tx),
            ("ty", ty)
        ])
    }
}

#if canImport(UIKit)
extension UIColor: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .color(TinkerbleColor(self)) }
}

extension TinkerbleColor {
    public init(_ color: UIColor) {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
}
#elseif canImport(AppKit)
extension NSColor: TinkerbleLogValueConvertible {
    public var tinkerbleLogValue: TinkerbleLogValue { .color(TinkerbleColor(self)) }
}

extension TinkerbleColor {
    public init(_ color: NSColor) {
        let resolved = color.usingColorSpace(.sRGB) ?? color
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent)
        )
    }
}
#endif

private extension TinkerbleColor {
    var logDisplayValue: String {
        "R \(byteString(red)) G \(byteString(green)) B \(byteString(blue)) A \(alphaString(alpha))"
    }

    func byteString(_ value: Double) -> String {
        let byte = Int((min(max(value, 0), 1) * 255).rounded())
        if byte < 10 {
            return "00\(byte)"
        }
        if byte < 100 {
            return "0\(byte)"
        }
        return "\(byte)"
    }

    func alphaString(_ value: Double) -> String {
        let scaled = Int((min(max(value, 0), 1) * 100).rounded())
        let whole = scaled / 100
        let fraction = scaled % 100
        if fraction < 10 {
            return "\(whole).0\(fraction)"
        }
        return "\(whole).\(fraction)"
    }
}

private extension String {
    func leftPaddedWithZeros(toLength length: Int) -> String {
        guard count < length else { return self }
        return String(repeating: "0", count: length - count) + self
    }
}
