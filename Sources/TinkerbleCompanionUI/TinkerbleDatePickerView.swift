import SwiftUI
import Tinkerble

#if os(macOS)
import AppKit

struct TinkerbleDatePickerView: NSViewRepresentable {
    @Binding var selection: Date
    var components: TinkerbleDateControlComponents

    func makeNSView(context: Context) -> NSDatePicker {
        let datePicker = NSDatePicker()
        datePicker.target = context.coordinator
        datePicker.action = #selector(Coordinator.dateChanged(_:))
        datePicker.isBordered = false
        datePicker.drawsBackground = true
        datePicker.isBezeled = true
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.alignment = .right
        updateNSView(datePicker, context: context)
        return datePicker
    }

    func updateNSView(_ datePicker: NSDatePicker, context: Context) {
        context.coordinator.parent = self
        let configuration = Self.appKitConfiguration(for: components)
        if datePicker.dateValue != selection {
            datePicker.dateValue = selection
        }
        datePicker.datePickerElements = configuration.elements
        datePicker.presentsCalendarOverlay = configuration.presentsCalendarOverlay
        datePicker.appearance = configuration.appearance
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func appKitConfiguration(for components: TinkerbleDateControlComponents) -> TinkerbleDatePickerAppKitConfiguration {
        switch components {
        case .date:
            TinkerbleDatePickerAppKitConfiguration(
                elements: .yearMonthDay,
                presentsCalendarOverlay: true,
                appearance: .tinkerbleDatePicker
            )
        case .dateAndTime:
            TinkerbleDatePickerAppKitConfiguration(
                elements: [.yearMonthDay, .hourMinute],
                presentsCalendarOverlay: true,
                appearance: .tinkerbleDatePicker
            )
        case .time:
            TinkerbleDatePickerAppKitConfiguration(
                elements: .hourMinute,
                presentsCalendarOverlay: false,
                appearance: .tinkerbleDatePicker
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: TinkerbleDatePickerView

        init(parent: TinkerbleDatePickerView) {
            self.parent = parent
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            parent.selection = sender.dateValue
        }
    }
}

struct TinkerbleDatePickerAppKitConfiguration: Equatable {
    var elements: NSDatePicker.ElementFlags
    var presentsCalendarOverlay: Bool
    var appearance: NSAppearance?
}

private extension NSAppearance {
    static var tinkerbleDatePicker: NSAppearance? {
        NSAppearance(named: .darkAqua)
    }
}
#else
struct TinkerbleDatePickerView: View {
    @Binding var selection: Date
    var components: TinkerbleDateControlComponents

    var body: some View {
        DatePicker("", selection: $selection, displayedComponents: displayedComponents)
            .labelsHidden()
            .datePickerStyle(.compact)
    }

    private var displayedComponents: DatePickerComponents {
        switch components {
        case .date:
            .date
        case .dateAndTime:
            [.date, .hourAndMinute]
        case .time:
            .hourAndMinute
        }
    }
}
#endif

#Preview("Date Picker") {
    @Previewable @State var date = Date(timeIntervalSinceReferenceDate: 804_729_600)

    TinkerbleDatePickerView(selection: $date, components: .dateAndTime)
        .padding()
}
