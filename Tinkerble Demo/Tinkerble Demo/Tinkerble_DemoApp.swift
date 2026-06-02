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
        Tinkerble.shared.connect(host: "127.0.0.1", port: 7777)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
