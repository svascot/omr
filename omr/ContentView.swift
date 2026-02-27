//
//  ContentView.swift
//  omr
//
//  Created by santiago vasco on 23/02/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.currentScreen {
            case .home:
                HomeView()
            case .recording:
                RecordingView()
            case .summary:
                SummaryView()
            case .history:
                HistoryView()
            }
        }
        .animation(.default, value: appState.currentScreen)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
