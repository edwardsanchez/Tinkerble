import Foundation
import SwiftUI
import Tinkerble

enum TinkerbleDemoSourceEditValidation {
    static let launchArgument = "--tinkerble-source-edit-validation"
    static let stringValue = "Applied \"String\"\nValue"
    static let boolValue = false
    static let colorValue = Color(.sRGB, red: 0.2, green: 0.7, blue: 0.35, opacity: 0.8)
    static let intValue = 42
    static let doubleValue = 0.875
    static let floatValue: Float = 2.5
    static let cgFloatValue: CGFloat = 24.5
    static let angleValue = Angle.degrees(63)
    static let dateValue = Date(timeIntervalSinceReferenceDate: 825_000_000)
    static let moodValue = DemoMood.celebratory

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}

struct SourceEditingDemoView: View {
    var stringValue: String
    var boolValue: Bool
    var colorValue: Color
    var intValue: Int
    var doubleValue: Double
    var floatValue: Float
    var cgFloatValue: CGFloat
    var angleValue: Angle
    var dateValue: Date
    var moodValue: DemoMood

    var body: some View {
        VStack(alignment: .leading) {
            Text("Source Editing Validation")
                .font(.headline)

            LabeledContent("String", value: stringValue)
            LabeledContent("Bool", value: boolValue ? "True" : "False")

            LabeledContent("Color") {
                Circle()
                    .fill(colorValue)
                    .frame(width: 18, height: 18)
            }

            LabeledContent("Int", value: intValue, format: .number)
            LabeledContent("Double", value: doubleValue, format: .number)
            LabeledContent("Float", value: floatValue, format: .number)
            LabeledContent("CGFloat", value: cgFloatValue, format: .number)
            LabeledContent("Angle", value: angleValue.degrees, format: .number)
            LabeledContent("Date", value: dateValue, format: .dateTime)
            LabeledContent("Mood", value: moodValue.tinkerbleDisplayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("TinkerbleSourceEditingValidation")
    }
}

#Preview("Source Editing Values") {
    SourceEditingDemoView(
        stringValue: TinkerbleDemoSourceEditValidation.stringValue,
        boolValue: TinkerbleDemoSourceEditValidation.boolValue,
        colorValue: TinkerbleDemoSourceEditValidation.colorValue,
        intValue: TinkerbleDemoSourceEditValidation.intValue,
        doubleValue: TinkerbleDemoSourceEditValidation.doubleValue,
        floatValue: TinkerbleDemoSourceEditValidation.floatValue,
        cgFloatValue: TinkerbleDemoSourceEditValidation.cgFloatValue,
        angleValue: TinkerbleDemoSourceEditValidation.angleValue,
        dateValue: TinkerbleDemoSourceEditValidation.dateValue,
        moodValue: TinkerbleDemoSourceEditValidation.moodValue
    )
    .padding()
}
