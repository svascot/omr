import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var isVisible = false
    
    var sortedHistory: [SessionStats] {
        appState.sessionHistory.sorted(by: { $0.date > $1.date })
    }
    
    var body: some View {
        ZStack {
            // Background Theme
            Color.black.ignoresSafeArea()
            
            // Decorative background elements
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 150, y: 300)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        appState.goHome()
                    }) {
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("HISTORY")
                            .font(.system(size: 14, weight: .black))
                            .tracking(2)
                            .foregroundStyle(.white)
                        
                        Text("\(appState.sessionHistory.count) SESSIONS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(0.5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                if sortedHistory.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No sessions recorded yet")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(sortedHistory) { session in
                                HistoryCard(session: session) {
                                    withAnimation(.spring()) {
                                        appState.deleteSession(id: session.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
        }
    }
}
    }
}

struct HistoryCard: View {
    let session: SessionStats
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened).uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.blue)
                        .tracking(1)
                    
                    Text((session.sessionName?.isEmpty == false) ? session.sessionName! : "Training Session")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                    Text(session.user)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(8)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    HistoryMetric(label: "REPS", value: "\(session.reps)", icon: "figure.strengthtraining.traditional")
                    HistoryMetric(label: "ACTIVE", value: formatTime(session.duration), icon: "timer")
                }
                
                HStack(spacing: 12) {
                    HistoryMetric(label: "TOTAL", value: formatTime(session.totalDuration), icon: "clock.fill")
                    HistoryMetric(label: "SETS", value: "\(session.sets)", icon: "list.bullet.indent", color: .purple)
                    HistoryMetric(label: "STREAK", value: "\(session.streak)", icon: "flame.fill", color: .orange)
                }
            }
        }
        .padding(20)
        .background(Rectangle().fill(.ultraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%01d:%02d", mins, secs)
    }
}

struct HistoryMetric: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.4))
            
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}
