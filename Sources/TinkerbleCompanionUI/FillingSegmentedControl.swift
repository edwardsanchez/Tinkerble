import AppKit

final class FillingSegmentedControl: NSSegmentedControl {
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width = NSView.noIntrinsicMetric
        return size
    }

    /// The size AppKit would give the segments without the width override above.
    var naturalSize: NSSize {
        super.intrinsicContentSize
    }

    var labels: [String] {
        (0..<segmentCount).map { label(forSegment: $0) ?? "" }
    }
}
