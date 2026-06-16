import AppKit

final class FillingSegmentedControl: NSSegmentedControl {
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width = NSView.noIntrinsicMetric
        return size
    }

    var labels: [String] {
        (0..<segmentCount).map { label(forSegment: $0) ?? "" }
    }
}
