//
//  ContentView.swift
//  Tinkerble Demo
//
//  Created by Edward Sanchez on 6/2/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Basic", systemImage: "slider.horizontal.3") {
                NavigationStack {
                    BasicDemoView()
                }
            }

            Tab("Fan Deck", systemImage: "rectangle.portrait.on.rectangle.portrait.angled.fill") {
                NavigationStack {
                    FanDeckDemoView()
                }
            }

            Tab("Logs", systemImage: "list.dash.header.rectangle.fill") {
                NavigationStack {
                    LogsDemoView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

#Preview("Basic Demo") {
    NavigationStack {
        BasicDemoView()
    }
}

#Preview("Logs Demo") {
    NavigationStack {
        LogsDemoView()
    }
}
