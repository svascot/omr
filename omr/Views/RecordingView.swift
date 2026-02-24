import SwiftUI
import Combine

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @State private var mockReps: Int = 0
    @State private var timeElapsed: TimeInterval = 0
    
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
                        
                        Text("\(mockReps)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    Spacer()
                    
                    // Timer
                    Text(formatTime(timeElapsed))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
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
                            Image(systemName: cameraManager.status == .paused ? "play.fill" : "pause.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill")
                            Text("OPEN PALM")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // Stop/Finish (Peace Sign)
                    VStack(spacing: 12) {
                        Button(action: {
                            cameraManager.stopRecording { url in
                                appState.endTraining(reps: mockReps, duration: timeElapsed)
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
                            Image(systemName: "hand.point.up.left.fill")
                            Text("PEACE SIGN")
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
            if cameraManager.status == .recording {
                timeElapsed += 1
            }
        }
        .onAppear {
            cameraManager.startRecording()
        }
        .statusBarHidden()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

#Preview {
    RecordingView()
        .environmentObject(AppState())
}
