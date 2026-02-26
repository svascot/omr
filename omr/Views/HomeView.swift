import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1), Color(uiColor: .systemBackground)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back,")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Text("Santiago")
                                .font(.system(.largeTitle, design: .rounded))
                                .fontWeight(.black)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        
                        // Streak Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("MY PROGRESS")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .tracking(1.5)
                                Spacer()
                            }
                            
                            HStack(spacing: 20) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                    )
                                    .shadow(color: .orange.opacity(0.4), radius: 10)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(appState.lastSession.streak)")
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                    Text("Day Streak")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        
                        // Last Session Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("LAST SESSION")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .tracking(1.5)
                                Spacer()
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(title: "Reps", value: "\(appState.lastSession.reps)", icon: "figure.strengthtraining.traditional", color: .blue)
                                StatCard(title: "Duration", value: formatTime(appState.lastSession.duration), icon: "timer", color: .purple)
                            }
                        }
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120) // Space for floating button
                }
                
                // Bottom Button Action
                VStack {
                    Button(action: {
                        withAnimation {
                            appState.startTraining()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.title3)
                            Text("START TRAINING")
                                .font(.headline)
                                .fontWeight(.bold)
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
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
    HomeView()
        .environmentObject(AppState())
}
