import SwiftUI
import Combine

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @State private var mockReps: Int = 0
    @State private var timeElapsed: TimeInterval = 0
    @State private var totalTimeElapsed: TimeInterval = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Real Camera Feed
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            
            // Subtle "Camera Feed" simulated gradient per design context
            LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.3)], 
                           startPoint: .top, 
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack {
                // Top Bar: Rep Counter
                HStack {
                    VStack(alignment: .leading, spacing: -5) {
                        Text("REPS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Text("\(cameraManager.movementService.repCount)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    Spacer()
                    
                    // Timers
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("SERIES")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(formatTime(timeElapsed))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        HStack(spacing: 8) {
                            Text("TOTAL")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(formatTime(totalTimeElapsed))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.3))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                // Interaction Overlays / Gesture Hints
                HStack(spacing: 60) {
                    // Pause/Resume (Open Palm)
                    VStack(spacing: 12) {
                        Button(action: { 
                            if cameraManager.status == .recording {
                                cameraManager.pauseRecording()
                            } else if cameraManager.status == .paused {
                                cameraManager.resumeRecording()
                            } else {
                                cameraManager.startRecording()
                            }
                        }) {
                            Image(systemName: recordingIcon)
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(recordingButtonColor)
                                .clipShape(Circle())
                        }
                        
                        HStack(spacing: 4) {
                            Text("✌️")
                            Text("Start/Pause")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // Stop/Finish (Peace Sign)
                    VStack(spacing: 12) {
                        Button(action: {
                            cameraManager.stopRecording { url in
                                appState.endTraining(reps: cameraManager.movementService.repCount, 
                                                   duration: timeElapsed, 
                                                   totalDuration: totalTimeElapsed, 
                                                   videoURL: url)
                            }
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        
                        HStack(spacing: 4) {
                            Text("👋")
                            Text("Finish Session")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 60)
            }
            
            // Camera Status Overlay (Error handling)
            if case .error(let message) = cameraManager.status {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onReceive(timer) { _ in
            totalTimeElapsed += 1
            if cameraManager.status == .recording {
                timeElapsed += 1
            }
            cameraManager.updateOverlayTimers(series: timeElapsed, total: totalTimeElapsed)
        }
        .onChange(of: cameraManager.detectedGesture) { oldValue, newValue in
            guard let gesture = newValue else { return }
            handleGesture(gesture)
            cameraManager.detectedGesture = nil // Reset
        }
        .onAppear {
            // Manual start requested - removed cameraManager.startRecording()
        }
        .statusBarHidden()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var recordingButtonColor: Color {
        switch cameraManager.status {
        case .recording: return .red
        case .paused: return .red.opacity(0.5)
        default: return .gray.opacity(0.8)
        }
    }
    
    private var recordingIcon: String {
        switch cameraManager.status {
        case .recording: return "pause.fill"
        case .paused: return "play.fill"
        default: return "circle.fill"
        }
    }
    
    private func handleGesture(_ gesture: CameraManager.GestureAction) {
        switch gesture {
        case .peace:
            if cameraManager.status == .recording {
                cameraManager.pauseRecording()
            } else if cameraManager.status == .paused {
                cameraManager.resumeRecording()
            } else {
                cameraManager.startRecording()
            }
        case .wave:
            cameraManager.stopRecording { url in
                appState.endTraining(reps: cameraManager.movementService.repCount, 
                                   duration: timeElapsed, 
                                   totalDuration: totalTimeElapsed, 
                                   videoURL: url)
            }
        }
    }
}

#Preview {
    RecordingView()
        .environmentObject(AppState())
}
