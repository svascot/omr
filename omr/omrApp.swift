//
//  omrApp.swift
//  omr
//
//  Created by santiago vasco on 23/02/26.
//

import SwiftUI

@main
struct omrApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
