import CoreGraphics

public enum TinkerbleCompanionEmptyStateLayout {
    public static let imageResourceName = "wings"
    public static let imageResourceExtension = "pdf"
    public static let imageWidth: CGFloat = 100

    public static var contentHeight: CGFloat {
        TinkerbleCompanionWindowLayout.minimumHeight
            - TinkerbleCompanionWindowLayout.titleBarHeight
            - TinkerbleCompanionWindowLayout.inspectorTopPadding
            - TinkerbleCompanionWindowLayout.inspectorBottomPadding
    }
}
