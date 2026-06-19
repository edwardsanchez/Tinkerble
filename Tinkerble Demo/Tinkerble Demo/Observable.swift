//
//  Obervable.swift
//  Tinkerble Demo
//
//  Created by Edward Sanchez on 6/15/26.
//

import SwiftUI
import Observation
import Tinkerble

enum DemoMood: String, CaseIterable, TinkerbleEnum {
    case calm
    case focused
    case celebratory
}

@TinkerbleObservable
@Observable
@MainActor
final class ObservableDemoModel {
    @TinkerbleObservableState("Badge Text", screen: "Basic", category: "Observable")
    var badgeText = "Observable Model"

    @TinkerbleObservableState("Badge Enabled", screen: "Basic", category: "Observable")
    var badgeEnabled = true

    @TinkerbleObservableState("Badge Count", screen: "Basic", category: "Observable", control: TinkerbleControl<Int>.plain)
    var badgeCount = 2

    @TinkerbleObservableState("Badge Opacity", screen: "Basic", category: "Observable", control: .slider(0.0...1.0))
    var badgeOpacity = 0.9

    @TinkerbleObservableState("Badge Mood", screen: "Basic", category: "Observable")
    var badgeMood = DemoMood.calm
}

@TinkerbleActions
@Observable
@MainActor
final class ActionDemoModel {
    var actionCount = 0

    init() {
        activateTinkerbleActions()
    }

    @TinkerbleAction("Increment Action Count", screen: "Basic", category: "Observable")
    func incrementActionCount() {
        actionCount += 1
    }
}
