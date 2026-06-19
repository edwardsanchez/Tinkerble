//
//  BasicDemoView.swift
//  Tinkerble Demo
//
//  Created by Edward Sanchez on 6/15/26.
//

import SwiftUI
import Tinkerble

struct BasicDemoView: View {
    @State private var observableModel = ObservableDemoModel()
    @State private var actionModel = ActionDemoModel()

    @TinkerbleState("Title", screen: "Basic")
    private var title = "Tinkerble Demo"

    @TinkerbleState("Enabled", screen: "Basic", category: "Flags")
    private var isEnabled = true

    @TinkerbleState("Accent Color", screen: "Basic", category: "Palette")
    private var accentColor = Color.blue

    @TinkerbleState("Card Count", screen: "Basic", category: "Layout")
    private var cardCount = 3

    @TinkerbleState("Opacity", screen: "Basic", category: "Layout", control: .slider(0.0...1.0))
    private var opacity = 0.82

    @TinkerbleState("Mood", screen: "Basic", category: "Modes")
    private var mood = DemoMood.focused

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                sampleCards
                observableExamples
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
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

    private var observableExamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(observableModel.badgeText)
                .font(.headline)
                .foregroundStyle(observableModel.badgeEnabled ? .primary : .secondary)

            HStack(spacing: 10) {
                ForEach(0..<max(1, observableModel.badgeCount), id: \.self) { index in
                    Text("\(index + 1)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(accentColor.opacity(observableModel.badgeOpacity))
                        .clipShape(Circle())
                }
            }

            Text("Observable mood: \(observableModel.badgeMood.tinkerbleDisplayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Observable actions: \(actionModel.actionCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
