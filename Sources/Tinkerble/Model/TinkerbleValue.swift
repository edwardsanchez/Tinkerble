import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TinkerbleValueKind: String, Codable, Hashable {
    case string
    case bool
    case color
    case number
    case date
    case enumeration
    case action
}

public struct TinkerbleColor: Codable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(_ color: Color) {
        #if canImport(UIKit)
        let platformColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
        }
        #elseif canImport(AppKit)
        let platformColor = NSColor(color)
        let resolved = platformColor.usingColorSpace(.sRGB) ?? platformColor
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            alpha: Double(resolved.alphaComponent)
        )
        #else
        self.init(red: 0, green: 0, blue: 0, alpha: 1)
        #endif
    }

    public var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

public enum TinkerbleValue: Codable, Equatable, Hashable {
    case string(String)
    case bool(Bool)
    case color(TinkerbleColor)
    case number(Double)
    case date(Date)
    case enumCase(String)
    case action

    public var kind: TinkerbleValueKind {
        switch self {
        case .string:
            return .string
        case .bool:
            return .bool
        case .color:
            return .color
        case .number:
            return .number
        case .date:
            return .date
        case .enumCase:
            return .enumeration
        case .action:
            return .action
        }
    }
}
