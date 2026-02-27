import SwiftUI
import Combine
import Photos

enum AppScreen {
    case home
    case recording
    case summary
    case history
}

struct SessionStats: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var user: String = "vasco"
    var reps: Int
    var duration: TimeInterval // Active recording time
    var totalDuration: TimeInterval // Total time from landing on screen
    var streak: Int
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var sessionHistory: [SessionStats] = []
    @Published var currentUser: String = "vasco"
    @Published var lastVideoURL: URL?
    @Published var videoSaved: Bool = false
    
    var lastSession: SessionStats? {
        sessionHistory.last
    }
    
    private let storageURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("user_data_v2.json")
    
    init() {
        loadData()
    }
    
    // Action to start training
    func startTraining() {
        lastVideoURL = nil // Clear stale URL from previous session
        videoSaved = false
        currentScreen = .recording
    }
    
    // Action to end training
    func endTraining(reps: Int, duration: TimeInterval, totalDuration: TimeInterval, videoURL: URL?) {
        // Relaxed streak logic: count if reps > 0 OR session was long enough (e.g. > 5s)
        let previousStreak = sessionHistory.last?.streak ?? 0
        let newStreak = (reps > 0 || duration > 5) ? previousStreak + 1 : previousStreak
        
        let newSession = SessionStats(
            user: currentUser,
            reps: reps,
            duration: duration,
            totalDuration: totalDuration,
            streak: newStreak
        )
        
        sessionHistory.append(newSession)
        lastVideoURL = videoURL
        currentScreen = .summary
        saveData()
    }
    
    // Action to navigate to history
    func showHistory() {
        currentScreen = .history
    }
    
    // Action to save video to library
    func saveVideoToLibrary() {
        guard let url = lastVideoURL else {
            print("DEBUG: No video URL available to save.")
            return
        }
        
        // Ensure file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("DEBUG: Video file does not exist at path: \(url.path)")
            return
        }
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.videoSaved = true
                            print("DEBUG: Video saved to camera roll successfully!")
                        } else {
                            print("DEBUG: Error saving video to camera roll: \(error?.localizedDescription ?? "unknown error")")
                        }
                    }
                }

            case .denied, .restricted:
                print("DEBUG: Photo Library access denied or restricted.")
            case .notDetermined:
                print("DEBUG: Photo Library access not determined.")
            @unknown default:
                print("DEBUG: Unknown Photo Library authorization status.")
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
            let data = try JSONEncoder().encode(sessionHistory)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save data: \(error)")
        }
    }
    
    private func loadData() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            sessionHistory = try JSONDecoder().decode([SessionStats].self, from: data)
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}
