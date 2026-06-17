import CoreGraphics
import Foundation

public enum TinkerbleLogValue: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)

    public var displayValue: String {
        switch self {
        case let .string(value):
            return value
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        }
    }

    fileprivate static func labeledComponents(_ components: [(String, Double)]) -> TinkerbleLogValue {
        .string(components.map { label, value in "\(label): \(String(value))" }.joined(separator: ", "))
    }
}

public protocol TinkerbleLogValueConvertible {
    var tinkerbleLogValue: TinkerbleLogValue { get }
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
