import SwiftUI
import Combine
import Photos

enum AppScreen {
    case home
    case recording
    case summary
}

struct SessionStats: Codable {
    var reps: Int
    var duration: TimeInterval // Active recording time
    var totalDuration: TimeInterval // Total time from landing on screen
    var streak: Int
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var lastSession: SessionStats = SessionStats(reps: 0, duration: 0, totalDuration: 0, streak: 0)
    @Published var lastVideoURL: URL?
    
    private let storageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user_data.json")
    
    init() {
        loadData()
    }
    
    // Action to start training
    func startTraining() {
        lastVideoURL = nil // Clear stale URL from previous session
        currentScreen = .recording
    }
    
    // Action to end training
    func endTraining(reps: Int, duration: TimeInterval, totalDuration: TimeInterval, videoURL: URL?) {
        // Relaxed streak logic: count if reps > 0 OR session was long enough (e.g. > 5s)
        let newStreak = (reps > 0 || duration > 5) ? lastSession.streak + 1 : lastSession.streak
        lastSession = SessionStats(reps: reps, duration: duration, totalDuration: totalDuration, streak: newStreak)
        lastVideoURL = videoURL
        currentScreen = .summary
        saveData()
    }
    
    // Action to save video to library
    func saveVideoToLibrary() {
        guard let url = lastVideoURL else { return }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    if success {
                        print("Video saved successfully!")
                    } else {
                        print("Error saving video: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }
        }
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
