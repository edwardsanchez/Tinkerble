import CoreGraphics
import Foundation
import SwiftUI

public protocol TinkerbleValueConvertible {
    static var tinkerbleValueKind: TinkerbleValueKind { get }
    static var tinkerbleEnumOptions: [TinkerbleEnumOption]? { get }

    var tinkerbleValue: TinkerbleValue { get }
    static func fromTinkerbleValue(_ value: TinkerbleValue) -> Self?
}

public extension TinkerbleValueConvertible {
    static var tinkerbleEnumOptions: [TinkerbleEnumOption]? { nil }
}

extension String: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .string }
    public var tinkerbleValue: TinkerbleValue { .string(self) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> String? {
        guard case let .string(string) = value else { return nil }
        return string
    }
}

extension Bool: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .bool }
    public var tinkerbleValue: TinkerbleValue { .bool(self) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> Bool? {
        guard case let .bool(bool) = value else { return nil }
        return bool
    }
}

extension Int: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .number }
    public var tinkerbleValue: TinkerbleValue { .number(Double(self)) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> Int? {
        guard case let .number(number) = value else { return nil }
        return Int(number.rounded())
    }
}

extension Double: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .number }
    public var tinkerbleValue: TinkerbleValue { .number(self) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> Double? {
        guard case let .number(number) = value else { return nil }
        return number
    }
}

extension Float: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .number }
    public var tinkerbleValue: TinkerbleValue { .number(Double(self)) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> Float? {
        guard case let .number(number) = value else { return nil }
        return Float(number)
    }
}

extension CGFloat: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .number }
    public var tinkerbleValue: TinkerbleValue { .number(Double(self)) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> CGFloat? {
        guard case let .number(number) = value else { return nil }
        return CGFloat(number)
    }
}

extension Color: TinkerbleValueConvertible {
    public static var tinkerbleValueKind: TinkerbleValueKind { .color }
    public var tinkerbleValue: TinkerbleValue { .color(TinkerbleColor(self)) }

    public static func fromTinkerbleValue(_ value: TinkerbleValue) -> Color? {
        guard case let .color(color) = value else { return nil }
        return color.swiftUIColor
    }
}

public protocol TinkerbleEnum: TinkerbleValueConvertible, CaseIterable, Hashable {
    var tinkerbleEnumID: String { get }
    var tinkerbleDisplayName: String { get }
    static func tinkerbleCase(for id: String) -> Self?
}

public extension TinkerbleEnum where AllCases: Collection {
    static var tinkerbleValueKind: TinkerbleValueKind { .enumeration }

    static var tinkerbleEnumOptions: [TinkerbleEnumOption]? {
        allCases.map { option in
            TinkerbleEnumOption(id: option.tinkerbleEnumID, displayName: option.tinkerbleDisplayName)
        }
    }

    var tinkerbleValue: TinkerbleValue { .enumCase(tinkerbleEnumID) }

    static func fromTinkerbleValue(_ value: TinkerbleValue) -> Self? {
        guard case let .enumCase(id) = value else { return nil }
        return tinkerbleCase(for: id)
    }
}

public extension TinkerbleEnum where Self: RawRepresentable, RawValue == String, AllCases: Collection {
    var tinkerbleEnumID: String { rawValue }

    var tinkerbleDisplayName: String {
        rawValue
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    static func tinkerbleCase(for id: String) -> Self? {
        Self(rawValue: id)
    }
}
