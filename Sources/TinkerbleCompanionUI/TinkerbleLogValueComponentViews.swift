import SwiftUI
import Tinkerble

struct TinkerbleLogColorValueView: View {
    var color: TinkerbleColor

    private var channels: [TinkerbleLogTextComponent] {
        [
            .init(label: "R", value: byteString(color.red)),
            .init(label: "G", value: byteString(color.green)),
            .init(label: "B", value: byteString(color.blue)),
            .init(label: "A", value: alphaString(color.alpha))
        ]
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ForEach(channels.indices, id: \.self) { index in
                TinkerbleLogTextComponentView(component: channels[index])

                if index < channels.index(before: channels.endIndex) {
                    TinkerbleLogComponentDividerView()
                }
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(color.swiftUIColor)
                .frame(width: 28, height: 16)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func byteString(_ value: Double) -> String {
        let byte = Int((min(max(value, 0), 1) * 255).rounded())
        if byte < 10 {
            return "00\(byte)"
        }
        if byte < 100 {
            return "0\(byte)"
        }
        return "\(byte)"
    }

    private func alphaString(_ value: Double) -> String {
        let scaled = Int((min(max(value, 0), 1) * 100).rounded())
        let whole = scaled / 100
        let fraction = scaled % 100
        if fraction < 10 {
            return "\(whole).0\(fraction)"
        }
        return "\(whole).\(fraction)"
    }
}

struct TinkerbleLogTextComponent: Identifiable {
    var id: String { label }
    var label: String
    var value: String
}

struct TinkerbleLogTextComponentView: View {
    var component: TinkerbleLogTextComponent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(component.label)
                .bold()

            Text(component.value)
                .monospacedDigit()
        }
        .lineLimit(1)
    }
}

struct TinkerbleLogComponentDividerView: View {
    private static let baselineInset: CGFloat = 3

    var body: some View {
        Capsule()
            .fill(.tertiary)
            .frame(width: 1, height: 14)
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[VerticalAlignment.bottom] - Self.baselineInset
            }
            .accessibilityHidden(true)
    }
}

#Preview("Log Color Value") {
    TinkerbleLogColorValueView(color: TinkerbleColor(red: 0.38, green: 0.39, blue: 0.88, alpha: 1))
        .padding()
        .frame(width: 360)
}
