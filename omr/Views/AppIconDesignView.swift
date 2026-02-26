import SwiftUI

struct AppIconDesignView: View {
    var body: some View {
        ZStack {
            // Background Mesh Gradient
            LinearGradient(colors: [.blue, .purple, .blue.opacity(0.8)], 
                           startPoint: .topLeading, 
                           endPoint: .bottomTrailing)
            
            // Sub-gradient for depth
            Circle()
                .fill(RadialGradient(colors: [.cyan.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 200))
                .offset(x: -100, y: -100)
            
            // Central Symbol
            ZStack {
                // Outer Glowing Ring
                Circle()
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 12
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 1)
                    .shadow(color: .blue.opacity(0.5), radius: 20)
                
                // Stylized "R" (One More Rep)
                Text("R")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            
            // Glassmorphic Gloss Overlay
            LinearGradient(colors: [.white.opacity(0.2), .clear, .white.opacity(0.05)], 
                           startPoint: .topLeading, 
                           endPoint: .bottomTrailing)
                .blendMode(.overlay)
        }
        .frame(width: 512, height: 512)
        .clipShape(RoundedRectangle(cornerRadius: 110, style: .continuous))
        .padding(40)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    AppIconDesignView()
}
