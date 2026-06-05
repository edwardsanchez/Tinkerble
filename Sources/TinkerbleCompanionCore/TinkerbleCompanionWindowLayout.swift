import CoreGraphics

public enum TinkerbleCompanionWindowLayout {
    public static let width: CGFloat = 340
    public static let minimumHeight: CGFloat = 340
    public static let idealMaximumHeight: CGFloat = 640
    public static let titleBarHeight: CGFloat = 20
    public static let inspectorHorizontalPadding: CGFloat = 18
    public static let inspectorTopPadding: CGFloat = 14
    public static let inspectorBottomPadding: CGFloat = 18

    public static func maximumHeight(forMeasuredInspectorHeight inspectorHeight: CGFloat) -> CGFloat {
        max(minimumHeight, ceil(titleBarHeight + inspectorHeight))
    }

    public static func preferredHeight(forMeasuredInspectorHeight inspectorHeight: CGFloat) -> CGFloat {
        min(maximumHeight(forMeasuredInspectorHeight: inspectorHeight), idealMaximumHeight)
    }
}
