import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Hello, Santiago!")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Ready for another rep?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 40)
            
            Spacer()
            
            // Streak Badge
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(appState.lastSession.streak)")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Text("DAY STREAK")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
            
            Spacer()
            
            // Primary Action
            Button(action: {
                appState.startTraining()
            }) {
                Text("Train")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.bottom, 40)
            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .padding(.horizontal, 24)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
