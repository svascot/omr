import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Text("Training Stats")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Spacer()
            
            // Stats Grid
            VStack(spacing: 24) {
                StatRow(label: "Reps", value: "\(appState.lastSession.reps)", color: .blue)
                StatRow(label: "Active Time", value: formatTime(appState.lastSession.duration), color: .green)
                StatRow(label: "Total Time", value: formatTime(appState.lastSession.totalDuration), color: .cyan)
                StatRow(label: "New Streak", value: "\(appState.lastSession.streak)", color: .orange)
            }
            .padding(30)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer Actions
            VStack(spacing: 16) {
                Button(action: {
                    appState.saveVideoToLibrary()
                    appState.saveAndReturnHome()
                }) {
                    Text("Save Session")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button(action: {
                    appState.discardAndReturnHome()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d min", mins, secs)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.black)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    SummaryView()
        .environmentObject(AppState())
}
