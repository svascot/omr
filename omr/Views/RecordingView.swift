import SwiftUI
import Combine

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @State private var timeElapsed: TimeInterval = 0
    @State private var totalTimeElapsed: TimeInterval = 0
    @State private var isVisible = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Real Camera Feed
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            
            // Subtle simulated gradient for UI legibility
            LinearGradient(colors: [.black.opacity(0.4), .clear, .black.opacity(0.5)], 
                           startPoint: .top, 
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar: Rep Counter and Timers
                HStack(alignment: .top) {
                    // Rep Counter Card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("\(cameraManager.movementService.repCount)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    // Timers Stack
                    VStack(alignment: .trailing, spacing: 12) {
                        TimerCard(label: "SERIES", time: formatTime(timeElapsed), isActive: cameraManager.status == .recording)
                        TimerCard(label: "TOTAL", time: formatTime(totalTimeElapsed), isActive: true, isSecondary: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .offset(y: isVisible ? 0 : -20)
                .opacity(isVisible ? 1 : 0)
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 32) {
                    ControlButton(
                        icon: recordingIcon,
                        label: cameraManager.status == .recording ? "Pause" : "Start",
                        emoji: "✌️",
                        color: recordingButtonColor,
                        action: {
                            withAnimation(.spring()) {
                                if cameraManager.status == .recording {
                                    cameraManager.pauseRecording()
                                } else if cameraManager.status == .paused {
                                    cameraManager.resumeRecording()
                                } else {
                                    cameraManager.startRecording()
                                }
                            }
                        }
                    )
                    
                    ControlButton(
                        icon: "stop.fill",
                        label: "Finish",
                        emoji: "👋",
                        color: .blue,
                        action: {
                            cameraManager.stopRecording { url in
                                appState.endTraining(reps: cameraManager.movementService.repCount, 
                                                   duration: timeElapsed, 
                                                   totalDuration: totalTimeElapsed, 
                                                   videoURL: url)
                                if url != nil {
                                    appState.saveVideoToLibrary()
                                }
                            }
                        }
                    )
                }
                .padding(.bottom, 60)
                .offset(y: isVisible ? 0 : 30)
                .opacity(isVisible ? 1 : 0)
            }
            
            // Camera Status Error Overlay
            if case .error(let message) = cameraManager.status {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(40)
            }
        }
        .onReceive(timer) { _ in
            totalTimeElapsed += 1
            if cameraManager.status == .recording {
                timeElapsed += 1
            }
            cameraManager.updateOverlayTimers(series: timeElapsed, total: totalTimeElapsed)
        }
        .onChange(of: cameraManager.detectedGesture) { _, newValue in
            guard let gesture = newValue else { return }
            handleGesture(gesture)
            cameraManager.detectedGesture = nil
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
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
        case .paused: return .orange
        default: return .white.opacity(0.2)
        }
    }
    
    private var recordingIcon: String {
        switch cameraManager.status {
        case .recording: return "pause.fill"
        case .paused: return "play.fill"
        default: return "play.fill"
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
                if url != nil {
                    appState.saveVideoToLibrary()
                }
            }
        }
    }
}

// MARK: - Helper Views

struct TimerCard: View {
    let label: String
    let time: String
    let isActive: Bool
    var isSecondary: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(1)
            
            Text(time)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(isActive ? .white : .white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSecondary ? Color.black.opacity(0.3) : .ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(isSecondary ? 0.1 : 0.2), lineWidth: 1)
        )
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let emoji: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 14) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        ZStack {
                            if color == .blue || color == .red || color == .orange {
                                LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            } else {
                                .ultraThinMaterial
                            }
                        }
                    )
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            
            VStack(spacing: 2) {
                Text(emoji)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.8))
        }
    }
}

#Preview {
    RecordingView()
        .environmentObject(AppState())
}
