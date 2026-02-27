import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var appState: AppState
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background Gradient (Matches HomeView)
            LinearGradient(colors: [Color.green.opacity(0.15), Color.blue.opacity(0.1), Color(uiColor: .systemBackground)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Training Complete!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Text("Summary")
                                .font(.system(.largeTitle, design: .rounded))
                                .fontWeight(.black)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        
                        // Main Stats Grid
                        VStack(spacing: 20) {
                            HStack(spacing: 16) {
                                SummaryStatCard(title: "Reps", value: "\(appState.lastSession?.reps ?? 0)", icon: "figure.strengthtraining.traditional", color: .blue)
                                SummaryStatCard(title: "Active", value: formatTime(appState.lastSession?.duration ?? 0), icon: "timer", color: .green)
                            }
                            
                            HStack(spacing: 16) {
                                SummaryStatCard(title: "Total Time", value: formatTime(appState.lastSession?.totalDuration ?? 0), icon: "clock.fill", color: .cyan)
                                SummaryStatCard(title: "Streak", value: "\(appState.lastSession?.streak ?? 0)", icon: "flame.fill", color: .orange)
                            }
                        }
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 140)
                }
                
                // Footer Buttons (Matches HomeView style)
                VStack(spacing: 16) {
                    // Save Video Button (one-time use)
                    if appState.lastVideoURL != nil {
                        Button(action: {
                            if !appState.videoSaved {
                                appState.saveVideoToLibrary()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: appState.videoSaved ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                    .font(.body)
                                Text(appState.videoSaved ? "VIDEO SAVED ✓" : "SAVE VIDEO")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .tracking(1)
                            }
                            .foregroundStyle(.white.opacity(appState.videoSaved ? 0.6 : 1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(
                                    colors: appState.videoSaved
                                        ? [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
                                        : [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: appState.videoSaved ? .clear : .green.opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .disabled(appState.videoSaved)
                        .animation(.spring(response: 0.3), value: appState.videoSaved)
                    }
                    
                    Button(action: {
                        appState.saveAndReturnHome()
                    }) {
                        Text("FINISH SESSION")
                            .font(.headline)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    
                    Button(action: {
                        appState.discardAndReturnHome()
                    }) {
                        Text("DISCARD DATA")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(
                    Color(uiColor: .systemBackground)
                        .opacity(0.8)
                        .background(.ultraThinMaterial)
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// Reusable Stat Card specifically for Summary (consistent with HomeView but slightly modified if needed)
struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    SummaryView()
        .environmentObject(AppState())
}
