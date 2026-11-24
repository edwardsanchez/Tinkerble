import SwiftUI

/// Lays out a value row: the name column on the left, the controls on the right.
///
/// The name column keeps `labelWidth` unless the controls cannot fit beside it. Then it gives
/// up just enough width, down to `minimumLabelWidth`, so a wide control such as a date and time
/// picker never makes the row wider than the space it is offered. Without this, one wide row
/// widened the whole inspector column, which changed width as screens were switched.
struct TweakRowLayout: Layout {
    var labelWidth: CGFloat = 116
    var minimumLabelWidth: CGFloat = 72
    var spacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let label = subviews.first, let controls = subviews.last, subviews.count == 2 else { return .zero }
        let widths = columnWidths(for: proposal.width, controls: controls)
        let labelSize = label.sizeThatFits(.init(width: widths.label, height: nil))
        let controlsSize = controls.sizeThatFits(.init(width: widths.controls, height: nil))
        return CGSize(
            width: widths.label + spacing + widths.controls,
            height: max(labelSize.height, controlsSize.height)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let label = subviews.first, let controls = subviews.last, subviews.count == 2 else { return }
        let widths = columnWidths(for: bounds.width, controls: controls)
        label.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: .init(width: widths.label, height: nil)
        )
        controls.place(
            at: CGPoint(x: bounds.maxX, y: bounds.minY),
            anchor: .topTrailing,
            proposal: .init(width: widths.controls, height: nil)
        )
    }

    private func columnWidths(
        for availableWidth: CGFloat?,
        controls: LayoutSubview
    ) -> (label: CGFloat, controls: CGFloat) {
        guard let availableWidth, availableWidth.isFinite else {
            return (labelWidth, controls.sizeThatFits(.unspecified).width)
        }
        let minimumControlsWidth = controls.sizeThatFits(.init(width: 0, height: nil)).width
        let label = min(labelWidth, max(minimumLabelWidth, availableWidth - spacing - minimumControlsWidth))
        return (label, max(0, availableWidth - spacing - label))
    }
}

#Preview("Row Layout") {
    @Previewable @State var date = Date(timeIntervalSinceReferenceDate: 804_729_600)
    @Previewable @State var title = "Tinkerble Demo"

    VStack(alignment: .leading, spacing: 10) {
        TweakRowLayout {
            Text("Title")
                .bold()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $title)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        TweakRowLayout {
            Text("Source Date And Time")
                .bold()
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            TinkerbleDatePickerView(selection: $date, components: .dateAndTime)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    .font(.callout)
    .padding(.horizontal, 18)
    .frame(width: 340)
}
