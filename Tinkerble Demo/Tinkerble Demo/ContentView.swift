//
//  ContentView.swift
//  Tinkerble Demo
//
//  Created by Edward Sanchez on 6/2/26.
//

import SwiftUI
import Tinkerble

private enum DemoMood: String, CaseIterable, TinkerbleEnum {
    case calm
    case focused
    case celebratory
}

struct ContentView: View {
    @TinkerbleState(name: "Title")
    private var title = "Tinkerble Demo"

    @TinkerbleState(category: "Flags", name: "Enabled")
    private var isEnabled = true

    @TinkerbleState(category: "Palette", name: "Accent Color")
    private var accentColor = Color.blue

    @TinkerbleState(category: "Layout", name: "Card Count", control: .stepper(step: 1))
    private var cardCount = 3

    @TinkerbleState(category: "Layout", name: "Opacity", control: .slider(0.0...1.0))
    private var opacity = 0.82

    @TinkerbleState(category: "Modes", name: "Mood")
    private var mood = DemoMood.focused

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    sampleCards
                    logButton
                }
                .padding(20)
            }
            .navigationTitle("Tinkerble")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }

            Text("Mood: \(mood.tinkerbleDisplayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sampleCards: some View {
        VStack(spacing: 12) {
            ForEach(0..<max(1, cardCount), id: \.self) { index in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(opacity))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardTitle(for: index))
                            .font(.headline)
                        Text(isEnabled ? "Live values are applied from the companion." : "Disabled from a tweak.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var logButton: some View {
        Button {
            TinkerLog.print("Demo log: \(title), mood \(mood.rawValue), cards \(cardCount)")
        } label: {
            Label("Send Demo Log", systemImage: "text.bubble")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(accentColor)
        .disabled(!isEnabled)
    }

    private func cardTitle(for index: Int) -> String {
        switch mood {
        case .calm:
            return "Calm Card \(index + 1)"
        case .focused:
            return "Focus Card \(index + 1)"
        case .celebratory:
            return "Launch Card \(index + 1)"
        }
    }
}

#Preview {
    ContentView()
}
