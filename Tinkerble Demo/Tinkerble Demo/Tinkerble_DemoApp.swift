//
//  Tinkerble_DemoApp.swift
//  Tinkerble Demo
//
//  Created by Edward Sanchez on 6/2/26.
//

import SwiftUI
import Tinkerble

@main
struct Tinkerble_DemoApp: App {
    init() {
        Tinkerble.shared.connect()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
