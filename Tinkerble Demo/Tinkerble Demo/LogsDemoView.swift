//
//  LogsDemoView.swift
//  Tinkerble Demo
//
//  Created by Codex on 6/17/26.
//

import SwiftUI
import Tinkerble

struct LogsDemoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                LogsDemoDragSurfaceView()
            }
            .padding(20)
        }
        .navigationTitle("Logs")
        .background(Color(.systemGroupedBackground))
    }
}

private struct LogsDemoDragSurfaceView: View {
    @State private var containerSize = CGSize.zero
    @State private var puckPosition = CGPoint.zero
    @State private var dragStartPosition: CGPoint?
    @State private var lastMotionSample: LogsDemoMotionSample?

    var body: some View {
        VStack {
            ZStack {
                LinearGradient(
                    colors: [LogsDemoTelemetry.startColor, LogsDemoTelemetry.endColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.18)

                Circle()
                    .fill(LogsDemoTelemetry.resolvedColor(for: puckPosition, in: containerSize))
                    .frame(width: LogsDemoTelemetry.puckSize, height: LogsDemoTelemetry.puckSize)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .position(puckPosition)
                    .gesture(dragGesture)
                    .accessibilityLabel("Log puck")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipShape(.rect(cornerRadius: 18))
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                containerSize = size
                guard puckPosition == .zero else { return }

                puckPosition = CGPoint(x: size.width / 2, y: size.height / 2)
                logValues(translation: .zero, velocity: .zero, isDragging: false)
            }
            Text("Drag the circle around to see live logs.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            guard containerSize != .zero else { return }

            logValues(translation: .zero, velocity: .zero, isDragging: false)
        }
        .onDisappear {
            dragStartPosition = nil
            lastMotionSample = nil
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = puckPosition
                    lastMotionSample = LogsDemoMotionSample(position: puckPosition, time: value.time)
                }

                let startPosition = dragStartPosition ?? puckPosition
                let proposedPosition = CGPoint(
                    x: startPosition.x + value.translation.width,
                    y: startPosition.y + value.translation.height
                )
                let nextPosition = LogsDemoTelemetry.clampedPosition(proposedPosition, in: containerSize)
                let velocity = resolvedVelocity(for: nextPosition, time: value.time)

                puckPosition = nextPosition
                logValues(translation: value.translation, velocity: velocity, isDragging: true)
            }
            .onEnded { value in
                let startPosition = dragStartPosition ?? puckPosition
                let proposedPosition = CGPoint(
                    x: startPosition.x + value.translation.width,
                    y: startPosition.y + value.translation.height
                )
                puckPosition = LogsDemoTelemetry.clampedPosition(proposedPosition, in: containerSize)
                logValues(translation: value.translation, velocity: .zero, isDragging: false)
                dragStartPosition = nil
                lastMotionSample = nil
            }
    }

    private func resolvedVelocity(for position: CGPoint, time: Date) -> CGVector {
        defer {
            lastMotionSample = LogsDemoMotionSample(position: position, time: time)
        }

        guard let lastMotionSample else { return .zero }

        let elapsed = max(time.timeIntervalSince(lastMotionSample.time), 1 / 120)
        return CGVector(
            dx: (position.x - lastMotionSample.position.x) / elapsed,
            dy: (position.y - lastMotionSample.position.y) / elapsed
        )
    }

    private func logValues(translation: CGSize, velocity: CGVector, isDragging: Bool) {
        let blendProgress = LogsDemoTelemetry.blendProgress(for: puckPosition, in: containerSize)
        let resolvedColor = LogsDemoTelemetry.resolvedColor(progress: blendProgress)

        TinkerLog.value("Position", value: puckPosition, screen: "Logs Demo", category: "Motion")
        TinkerLog.value("Translation", value: translation, screen: "Logs Demo", category: "Motion")
        TinkerLog.value("Velocity", value: velocity, screen: "Logs Demo", category: "Motion")
        TinkerLog.value(
            "Is Dragging",
            value: isDragging ? "true" : "false",
            screen: "Logs Demo",
            category: "Motion"
        )
        TinkerLog.value("Resolved Color", value: resolvedColor, screen: "Logs Demo", category: "Color")
        TinkerLog.value("Blend Progress", value: blendProgress, screen: "Logs Demo", category: "Color")
    }
}

private struct LogsDemoMotionSample {
    var position: CGPoint
    var time: Date
}

private enum LogsDemoTelemetry {
    static let puckSize = 76.0
    static let startColor = Color(red: 1, green: 0.22, blue: 0.58)
    static let endColor = Color(red: 0.12, green: 0.45, blue: 1)

    static func resolvedColor(for position: CGPoint, in size: CGSize) -> Color {
        resolvedColor(progress: blendProgress(for: position, in: size))
    }

    static func resolvedColor(progress: Double) -> Color {
        let progress = min(max(progress, 0), 1)
        return Color(
            red: 1 + (0.12 - 1) * progress,
            green: 0.22 + (0.45 - 0.22) * progress,
            blue: 0.58 + (1 - 0.58) * progress
        )
    }

    static func blendProgress(for position: CGPoint, in size: CGSize) -> Double {
        let minimumX = puckSize / 2
        let maximumX = max(minimumX, size.width - puckSize / 2)
        guard maximumX > minimumX else { return 0 }

        return min(max((position.x - minimumX) / (maximumX - minimumX), 0), 1)
    }

    static func clampedPosition(_ position: CGPoint, in size: CGSize) -> CGPoint {
        let radius = puckSize / 2
        let maximumX = max(radius, size.width - radius)
        let maximumY = max(radius, size.height - radius)

        return CGPoint(
            x: min(max(position.x, radius), maximumX),
            y: min(max(position.y, radius), maximumY)
        )
    }
}

#Preview("Logs Demo") {
    NavigationStack {
        LogsDemoView()
    }
}
