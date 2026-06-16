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
    @TinkerbleObservableState(category: "Observable", name: "Badge Text", screen: "Basic")
    var badgeText = "Observable Model"

    @TinkerbleObservableState(category: "Observable", name: "Badge Enabled", screen: "Basic")
    var badgeEnabled = true

    @TinkerbleObservableState(category: "Observable", name: "Badge Count", screen: "Basic", control: TinkerbleControl<Int>.plain)
    var badgeCount = 2

    @TinkerbleObservableState("Observable", name: "Badge Opacity", screen: "Basic", control: .slider(0.0...1.0))
    var badgeOpacity = 0.9

    @TinkerbleObservableState(category: "Observable", name: "Badge Mood", screen: "Basic")
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

    @TinkerbleAction(name: "Increment Action Count", screen: "Basic", category: "Observable")
    func incrementActionCount() {
        actionCount += 1
    }
}
