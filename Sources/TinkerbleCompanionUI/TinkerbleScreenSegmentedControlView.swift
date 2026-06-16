import SwiftUI

struct TinkerbleScreenSegmentedControlView: NSViewRepresentable {
    var screens: [String]
    @Binding var selectedScreen: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedScreen: $selectedScreen)
    }

    func makeNSView(context: Context) -> FillingSegmentedControl {
        let segmentedControl = FillingSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
        segmentedControl.segmentDistribution = .fillEqually
        segmentedControl.controlSize = .large
        segmentedControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmentedControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segmentedControl.target = context.coordinator
        segmentedControl.action = #selector(Coordinator.selectionDidChange(_:))
        segmentedControl.identifier = NSUserInterfaceItemIdentifier("TinkerbleScreenSegmentedControl")
        return segmentedControl
    }

    func updateNSView(_ segmentedControl: FillingSegmentedControl, context: Context) {
        context.coordinator.selectedScreen = $selectedScreen
        context.coordinator.screens = screens

        if segmentedControl.labels != screens {
            segmentedControl.segmentCount = screens.count
            for (index, screen) in screens.enumerated() {
                segmentedControl.setLabel(screen, forSegment: index)
            }
        }

        segmentedControl.selectedSegment = screens.firstIndex(of: selectedScreen) ?? -1
    }

    final class Coordinator: NSObject {
        var selectedScreen: Binding<String>
        var screens: [String] = []

        init(selectedScreen: Binding<String>) {
            self.selectedScreen = selectedScreen
        }

        @objc func selectionDidChange(_ sender: NSSegmentedControl) {
            let selectedIndex = sender.selectedSegment
            guard screens.indices.contains(selectedIndex) else { return }
            selectedScreen.wrappedValue = screens[selectedIndex]
        }
    }
}

#Preview("Screen Segments") {
    @Previewable @State var selectedScreen = "Fan Deck"

    TinkerbleScreenSegmentedControlView(
        screens: ["Basic", "Fan Deck"],
        selectedScreen: $selectedScreen
    )
    .frame(maxWidth: .infinity)
    .padding()
}
