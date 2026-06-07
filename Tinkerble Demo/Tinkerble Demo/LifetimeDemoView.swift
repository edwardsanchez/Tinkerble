import Observation
import SwiftUI
import Tinkerble

@Observable
@MainActor
private final class LifetimeObservableDemoModel {
    @ObservationIgnored
    @TinkerbleState(category: "Lifetime Observable", name: "Message")
    var message = "Observable scope loaded"

    @ObservationIgnored
    @TinkerbleState(category: "Lifetime Observable", name: "Enabled")
    var isEnabled = true

    @ObservationIgnored
    @TinkerbleState(category: "Lifetime Observable", name: "Count", control: TinkerbleControl<Int>.plain)
    var count = 3
}

struct LifetimeDemoView: View {
    @State private var showsStateScope = false
    @State private var showsObservableScope = false

    var body: some View {
        Form {
            Section("Mounted Scopes") {
                Toggle("State view loaded", isOn: $showsStateScope)
                Toggle("Observable view loaded", isOn: $showsObservableScope)
            }

            if showsStateScope {
                Section("@TinkerbleState") {
                    ScopedTinkerbleStateLifetimeView()
                }
            }

            if showsObservableScope {
                Section("@Observable + @TinkerbleState") {
                    ScopedTinkerbleObservableLifetimeView()
                }
            }

            Section("Pushed Scopes") {
                NavigationLink("Push state view") {
                    ScopedTinkerbleStateLifetimeView()
                }
                NavigationLink("Push observable view") {
                    ScopedTinkerbleObservableLifetimeView()
                }
            }
        }
        .navigationTitle("Lifetime")
    }
}

private struct ScopedTinkerbleStateLifetimeView: View {
    @TinkerbleState(category: "Lifetime State", name: "Message")
    private var message = "State scope loaded"

    @TinkerbleState(category: "Lifetime State", name: "Enabled")
    private var isEnabled = true

    @TinkerbleState(category: "Lifetime State", name: "Count", control: TinkerbleControl<Int>.plain)
    private var count = 3

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Message", text: $message)
            Toggle("Enabled", isOn: $isEnabled)
            Stepper(value: $count, in: 1...12) {
                Text("Count \(count)")
            }
            HStack {
                ForEach(0..<max(1, count), id: \.self) { index in
                    Image(systemName: isEnabled ? "\(index + 1).circle.fill" : "\(index + 1).circle")
                        .imageScale(.large)
                }
            }
            .foregroundStyle(isEnabled ? .primary : .secondary)
        }
    }
}

private struct ScopedTinkerbleObservableLifetimeView: View {
    @State private var model = LifetimeObservableDemoModel()

    var body: some View {
        VStack(alignment: .leading) {
            TextField(
                "Message",
                text: Binding(
                    get: { model.message },
                    set: { model.message = $0 }
                )
            )
            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.isEnabled = $0 }
                )
            )
            Stepper(
                value: Binding(
                    get: { model.count },
                    set: { model.count = $0 }
                ),
                in: 1...12
            ) {
                Text("Count \(model.count)")
            }
            HStack {
                ForEach(0..<max(1, model.count), id: \.self) { index in
                    Image(systemName: model.isEnabled ? "\(index + 1).square.fill" : "\(index + 1).square")
                        .imageScale(.large)
                }
            }
            .foregroundStyle(model.isEnabled ? .primary : .secondary)
        }
    }
}

#Preview("Lifetime Demo") {
    NavigationStack {
        LifetimeDemoView()
    }
}

#Preview("@TinkerbleState Scope") {
    Form {
        ScopedTinkerbleStateLifetimeView()
    }
}

#Preview("@Observable + @TinkerbleState Scope") {
    Form {
        ScopedTinkerbleObservableLifetimeView()
    }
}
