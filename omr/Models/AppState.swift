import SwiftUI
import Combine

enum AppScreen {
    case home
    case recording
    case summary
}

struct SessionStats {
    var reps: Int
    var duration: TimeInterval
    var streak: Int
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var lastSession: SessionStats = SessionStats(reps: 0, duration: 0, streak: 85)
    
    // Mocked action to start training
    func startTraining() {
        currentScreen = .recording
    }
    
    // Mocked action to end training
    func endTraining(reps: Int, duration: TimeInterval) {
        lastSession = SessionStats(reps: reps, duration: duration, streak: lastSession.streak + 1)
        currentScreen = .summary
    }
    
    // Mocked action to save and return home
    func saveAndReturnHome() {
        currentScreen = .home
    }
    
    // Mocked action to discard and return home
    func discardAndReturnHome() {
        currentScreen = .home
    }
}
