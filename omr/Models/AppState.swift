import SwiftUI
import Combine

enum AppScreen {
    case home
    case recording
    case summary
}

struct SessionStats: Codable {
    var reps: Int
    var duration: TimeInterval
    var streak: Int
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var lastSession: SessionStats = SessionStats(reps: 0, duration: 0, streak: 0)
    
    private let storageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user_data.json")
    
    init() {
        loadData()
    }
    
    // Action to start training
    func startTraining() {
        currentScreen = .recording
    }
    
    // Action to end training
    func endTraining(reps: Int, duration: TimeInterval) {
        // Simple streak logic: only increment if they actually did reps
        let newStreak = reps > 0 ? lastSession.streak + 1 : lastSession.streak
        lastSession = SessionStats(reps: reps, duration: duration, streak: newStreak)
        currentScreen = .summary
        saveData()
    }
    
    // Action to save and return home
    func saveAndReturnHome() {
        currentScreen = .home
        saveData()
    }
    
    // Action to discard and return home
    func discardAndReturnHome() {
        currentScreen = .home
    }
    
    private func saveData() {
        do {
            let data = try JSONEncoder().encode(lastSession)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save data: \(error)")
        }
    }
    
    private func loadData() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            lastSession = try JSONDecoder().decode(SessionStats.self, from: data)
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}
