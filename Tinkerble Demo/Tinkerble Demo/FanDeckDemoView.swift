//
//  FanDeckDemoView.swift
//  Tinkerble Demo
//
//  Created by Codex on 6/15/26.
//

import SwiftUI
import Tinkerble
import UIKit

struct FanDeckDemoView: View {
    @TinkerbleState(category: "Deck", name: "Card Count", screen: "Fan Deck", control: TinkerbleControl<Int>.slider(2...9))
    private var cardCount = 5

    @TinkerbleState(category: "Deck", name: "Card Size", screen: "Fan Deck", control: .slider(120.0...320.0))
    private var cardSize = 220.0

    @TinkerbleState(category: "Deck", name: "Card Spacing", screen: "Fan Deck", control: .slider(0.0...120.0))
    private var cardSpacing = 52.0

    @TinkerbleState(category: "Curve", name: "Spread Angle", screen: "Fan Deck", control: .slider(0.0...90.0))
    private var spreadAngle = 38.0

    @TinkerbleState(category: "Curve", name: "Arc Lift", screen: "Fan Deck", control: .slider(0.0...140.0))
    private var arcLift = 34.0

    @TinkerbleState(category: "Curve", name: "Edge Scale", screen: "Fan Deck", control: .slider(0.5...1.0))
    private var edgeScale = 1.0

    @TinkerbleState(category: "Appearance", name: "Corner Radius", screen: "Fan Deck", control: .slider(0.0...60.0))
    private var cornerRadius = 12.0

    @TinkerbleState(category: "Appearance", name: "Shadow Radius", screen: "Fan Deck", control: .slider(0.0...30.0))
    private var shadowRadius = 6.0

    @TinkerbleState(category: "Appearance", name: "Shadow Opacity", screen: "Fan Deck", control: .slider(0.0...1.0))
    private var shadowOpacity = 0.18

    @TinkerbleState(category: "Animation", name: "Duration", screen: "Fan Deck", control: .slider(0.1...2.0, step: 0.05, decimalPlaces: 2))
    private var duration = 0.45

    @TinkerbleState(category: "Animation", name: "Bounciness", screen: "Fan Deck", control: .slider(0.0...1.0))
    private var bounciness = 0.35

    @TinkerbleState(category: "Colors", name: "Start Color", screen: "Fan Deck")
    private var startColor = Color.blue

    @TinkerbleState(category: "Colors", name: "End Color", screen: "Fan Deck")
    private var endColor = Color.purple

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap the deck to replay the current spring.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FanDeckView(
                    cardCount: cardCount,
                    cardSize: cardSize,
                    cardSpacing: cardSpacing,
                    spreadAngle: spreadAngle,
                    arcLift: arcLift,
                    edgeScale: edgeScale,
                    cornerRadius: cornerRadius,
                    shadowRadius: shadowRadius,
                    shadowOpacity: shadowOpacity,
                    duration: duration,
                    bounciness: bounciness,
                    startColor: startColor,
                    endColor: endColor
                )
            }
            .padding(20)
        }
        .navigationTitle("Fan Deck")
        .background(Color(.systemGroupedBackground))
    }
}

private struct FanDeckView: View {
    let cardCount: Int
    let cardSize: Double
    let cardSpacing: Double
    let spreadAngle: Double
    let arcLift: Double
    let edgeScale: Double
    let cornerRadius: Double
    let shadowRadius: Double
    let shadowOpacity: Double
    let duration: Double
    let bounciness: Double
    let startColor: Color
    let endColor: Color

    @State private var isExpanded = false
    @State private var deckSize = CGSize.zero

    var body: some View {
        let resolvedSpreadAngle = isExpanded ? spreadAngle : 0
        let resolvedSpacing = isExpanded ? cardSpacing : 0
        let resolvedArcLift = isExpanded ? arcLift : 0
        let cards = FanDeckLayout.cards(count: cardCount)
        let bounds = FanDeckLayout.boundingRect(
            for: cards,
            cardHeight: cardSize,
            spacing: resolvedSpacing,
            spreadAngle: resolvedSpreadAngle,
            arcLift: resolvedArcLift,
            edgeScale: edgeScale
        )
        let fitScale = FanDeckLayout.fitScale(for: bounds, in: deckSize)

        ZStack {
            Color.clear
                .accessibilityHidden(true)

            ZStack {
                ForEach(cards) { card in
                    FanDeckCardView(
                        color: cardColor(for: card),
                        height: cardSize,
                        cornerRadius: cornerRadius
                    )
                    .scaleEffect(CGFloat(card.scale(edgeScale: edgeScale)))
                    .shadow(
                        color: .black.opacity(shadowOpacity),
                        radius: CGFloat(shadowRadius),
                        x: 0,
                        y: CGFloat(shadowRadius / 2)
                    )
                    .rotationEffect(.degrees(card.angle(spreadAngle: resolvedSpreadAngle)))
                    .offset(
                        x: CGFloat(card.xOffset(spacing: resolvedSpacing)),
                        y: CGFloat(card.yOffset(arcLift: resolvedArcLift))
                    )
                    .zIndex(Double(card.index))
                }
            }
            .scaleEffect(CGFloat(fitScale))
            .offset(
                x: -bounds.midX * CGFloat(fitScale),
                y: -bounds.midY * CGFloat(fitScale)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .contentShape(.rect)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            deckSize = size
        }
        .onTapGesture {
            replayFan()
        }
        .task {
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            expandFan()
        }
        .onDisappear {
            isExpanded = false
        }
    }

    private func cardColor(for card: FanDeckCardLayout) -> Color {
        let divisor = max(Double(cardCount - 1), 1)
        return Color.lerp(from: startColor, to: endColor, progress: Double(card.index) / divisor)
    }

    private func expandFan() {
        withAnimation(.spring(duration: duration, bounce: bounciness)) {
            isExpanded = true
        }
    }

    private func replayFan() {
        isExpanded = false

        Task {
            try? await Task.sleep(for: .seconds(0.08))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                expandFan()
            }
        }
    }
}

private struct FanDeckCardView: View {
    let color: Color
    let height: Double
    let cornerRadius: Double

    private static let widthRatio = 0.6

    var body: some View {
        RoundedRectangle(cornerRadius: CGFloat(cornerRadius))
            .fill(color)
            .frame(width: CGFloat(height * Self.widthRatio), height: CGFloat(height))
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat(cornerRadius))
                    .stroke(.white.opacity(0.4), lineWidth: 1)
            }
    }
}

private struct FanDeckCardLayout: Identifiable {
    let index: Int
    let centerIndex: Double
    let divisor: Double

    var id: Int { index }

    var relative: Double {
        Double(index) - centerIndex
    }

    var normalized: Double {
        relative / divisor
    }

    func angle(spreadAngle: Double) -> Double {
        normalized * spreadAngle / 2
    }

    func xOffset(spacing: Double) -> Double {
        relative * spacing
    }

    func yOffset(arcLift: Double) -> Double {
        arcLift * (normalized * normalized - 1)
    }

    func scale(edgeScale: Double) -> Double {
        1 - (1 - edgeScale) * abs(normalized)
    }
}

private enum FanDeckLayout {
    private static let horizontalInset = 24.0
    private static let verticalInset = 24.0
    private static let cardWidthRatio = 0.6

    static func cards(count: Int) -> [FanDeckCardLayout] {
        let resolvedCount = min(max(count, 2), 9)
        let centerIndex = Double(resolvedCount - 1) / 2
        let divisor = max(centerIndex, 1)

        return (0..<resolvedCount).map { index in
            FanDeckCardLayout(index: index, centerIndex: centerIndex, divisor: divisor)
        }
    }

    static func boundingRect(
        for cards: [FanDeckCardLayout],
        cardHeight: Double,
        spacing: Double,
        spreadAngle: Double,
        arcLift: Double,
        edgeScale: Double
    ) -> CGRect {
        let cardSize = CGSize(width: CGFloat(cardHeight * cardWidthRatio), height: CGFloat(cardHeight))
        let points = cards.flatMap { card in
            transformedCorners(
                size: cardSize,
                scale: card.scale(edgeScale: edgeScale),
                angleDegrees: card.angle(spreadAngle: spreadAngle),
                offset: CGSize(
                    width: CGFloat(card.xOffset(spacing: spacing)),
                    height: CGFloat(card.yOffset(arcLift: arcLift))
                )
            )
        }

        guard let first = points.first else { return .zero }

        let extremes = points.reduce((minX: first.x, maxX: first.x, minY: first.y, maxY: first.y)) { result, point in
            (
                minX: min(result.minX, point.x),
                maxX: max(result.maxX, point.x),
                minY: min(result.minY, point.y),
                maxY: max(result.maxY, point.y)
            )
        }

        return CGRect(
            x: extremes.minX,
            y: extremes.minY,
            width: extremes.maxX - extremes.minX,
            height: extremes.maxY - extremes.minY
        )
    }

    static func fitScale(for bounds: CGRect, in containerSize: CGSize) -> Double {
        guard bounds.width > 0, bounds.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return 1
        }

        let availableWidth = max(Double(containerSize.width) - horizontalInset * 2, 1)
        let availableHeight = max(Double(containerSize.height) - verticalInset * 2, 1)

        return min(1, availableWidth / Double(bounds.width), availableHeight / Double(bounds.height))
    }

    private static func transformedCorners(
        size: CGSize,
        scale: Double,
        angleDegrees: Double,
        offset: CGSize
    ) -> [CGPoint] {
        let halfWidth = Double(size.width) * scale / 2
        let halfHeight = Double(size.height) * scale / 2
        let radians = angleDegrees * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        return [
            CGPoint(x: CGFloat(-halfWidth), y: CGFloat(-halfHeight)),
            CGPoint(x: CGFloat(halfWidth), y: CGFloat(-halfHeight)),
            CGPoint(x: CGFloat(halfWidth), y: CGFloat(halfHeight)),
            CGPoint(x: CGFloat(-halfWidth), y: CGFloat(halfHeight))
        ].map { point in
            CGPoint(
                x: point.x * CGFloat(cosine) - point.y * CGFloat(sine) + offset.width,
                y: point.x * CGFloat(sine) + point.y * CGFloat(cosine) + offset.height
            )
        }
    }
}

private extension Color {
    static func lerp(from startColor: Color, to endColor: Color, progress: Double) -> Color {
        let resolvedProgress = min(max(progress, 0), 1)
        let startComponents = UIColor(startColor).rgbaComponents
        let endComponents = UIColor(endColor).rgbaComponents

        return Color(
            red: startComponents.red + (endComponents.red - startComponents.red) * resolvedProgress,
            green: startComponents.green + (endComponents.green - startComponents.green) * resolvedProgress,
            blue: startComponents.blue + (endComponents.blue - startComponents.blue) * resolvedProgress,
            opacity: startComponents.alpha + (endComponents.alpha - startComponents.alpha) * resolvedProgress
        )
    }
}

private extension UIColor {
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var alpha = CGFloat.zero

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}

#Preview("Fan-Out Deck") {
    NavigationStack {
        FanDeckDemoView()
    }
}
