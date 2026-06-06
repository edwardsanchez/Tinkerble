import AppKit
import SwiftUI
import TinkerbleCompanionCore

struct HudWindowConfigurator: NSViewRepresentable {
    var keepsWindowOnTop: Bool
    var measuredInspectorHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        window.title = "Tinkerble"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = false
        window.styleMask.insert(.titled)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.hudWindow)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.miniaturizable)
        window.level = keepsWindowOnTop ? .floating : .normal

        [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton,
        ].forEach { buttonType in
            window.standardWindowButton(buttonType)?.isHidden = true
        }

        let width = TinkerbleCompanionWindowLayout.width
        let minimumHeight = TinkerbleCompanionWindowLayout.minimumHeight
        let hasMeasuredContent = measuredInspectorHeight > 0
        let maximumHeight: CGFloat
        let preferredHeight: CGFloat
        if hasMeasuredContent {
            maximumHeight = TinkerbleCompanionWindowLayout.maximumHeight(
                forMeasuredInspectorHeight: measuredInspectorHeight
            )
            preferredHeight = TinkerbleCompanionWindowLayout.preferredHeight(
                forMeasuredInspectorHeight: measuredInspectorHeight
            )
        } else {
            maximumHeight = TinkerbleCompanionWindowLayout.idealMaximumHeight
            preferredHeight = TinkerbleCompanionWindowLayout.idealMaximumHeight
        }
        let chromeHeight = max(0, window.frame.height - (window.contentView?.bounds.height ?? window.frame.height))
        let contentMinimumHeight = max(1, minimumHeight - chromeHeight)
        let contentMaximumHeight = max(contentMinimumHeight, maximumHeight - chromeHeight)
        let currentHeight = window.frame.height
        let clampedHeight = min(max(currentHeight, minimumHeight), maximumHeight)
        let shouldClampToBounds = abs(currentHeight - clampedHeight) > 0.5
        let isStillAppManaged = coordinator.lastManagedHeight.map { abs(currentHeight - $0) <= 0.5 } ?? true
        let shouldApplyPreferredHeight = hasMeasuredContent &&
            isStillAppManaged &&
            abs(currentHeight - preferredHeight) > 0.5
        let targetHeight: CGFloat
        if shouldClampToBounds {
            targetHeight = clampedHeight
        } else if shouldApplyPreferredHeight {
            targetHeight = preferredHeight
        } else {
            targetHeight = currentHeight
        }

        window.minSize = CGSize(width: width, height: minimumHeight)
        window.maxSize = CGSize(width: width, height: maximumHeight)
        window.contentMinSize = CGSize(width: width, height: contentMinimumHeight)
        window.contentMaxSize = CGSize(width: width, height: contentMaximumHeight)

        if abs(window.frame.width - width) > 0.5 ||
            shouldClampToBounds ||
            shouldApplyPreferredHeight {
            let yDelta = currentHeight - targetHeight
            window.setFrame(
                NSRect(
                    x: window.frame.minX,
                    y: window.frame.minY + yDelta,
                    width: width,
                    height: targetHeight
                ),
                display: true
            )
            coordinator.lastManagedHeight = targetHeight
        } else if coordinator.lastManagedHeight == nil {
            coordinator.lastManagedHeight = currentHeight
        }
    }

    final class Coordinator {
        var lastManagedHeight: CGFloat?
    }
}
