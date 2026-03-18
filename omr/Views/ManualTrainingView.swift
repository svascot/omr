import SwiftUI
import Combine

struct ManualTrainingView: View {
    @EnvironmentObject var appState: AppState
    
    // MARK: - State
    @State private var isActive = false       // Timer running?
    @State private var isVisible = false      // Entrance animation
    @State private var timeElapsed: TimeInterval = 0
    @State private var selectedReps: Int = 5
    @State private var setLog: [Int] = []     // Each entry = reps in that set
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var totalReps: Int { setLog.reduce(0, +) }
    
    var body: some View {
        ZStack {
            // Background Gradient (consistent with HomeView)
            LinearGradient(colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1), Color(uiColor: .systemBackground)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        
                        // MARK: - Timer Section
                        VStack(spacing: 8) {
                            Text("TRAINING TIME")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(1.5)
                            
                            Text(formatTime(timeElapsed))
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: timeElapsed)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 20)
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        
                        // MARK: - Controls (Picker + Add + Start/Finish)
                        VStack(spacing: 14) {
                            if isActive {
                                VStack(spacing: 12) {
                                    HStack(spacing: 0) {
                                        Text("ADD")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .padding(.leading, 20)
                                        
                                        Picker("Reps", selection: $selectedReps) {
                                            ForEach(1...50, id: \.self) { num in
                                                Text("\(num)")
                                                    .font(.system(.title3, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .tag(num)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 80, height: 100)
                                        .clipped()
                                        
                                        Text("REPS")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.secondary)
                                            .padding(.trailing, 20)
                                    }
                                    
                                    Button(action: addSet) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                            Text("ADD \(selectedReps) REPS")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .tracking(1)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 6)
                                    }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            
                            // Start / Finish Button
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    if isActive {
                                        finishSession()
                                    } else {
                                        isActive = true
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isActive ? "checkmark.circle.fill" : "play.fill")
                                        .font(.title3)
                                    Text(isActive ? "FINISH SESSION" : "START TRAINING")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .tracking(1)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(
                                    LinearGradient(
                                        colors: isActive
                                            ? [Color.green, Color.green.opacity(0.8)]
                                            : [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: (isActive ? Color.green : Color.blue).opacity(0.4), radius: 15, x: 0, y: 8)
                            }
                        }
                        .offset(y: isVisible ? 0 : 20)
                        .opacity(isVisible ? 1 : 0)
                        
                        // MARK: - Total Reps Summary Card
                        if !setLog.isEmpty {
                            HStack(spacing: 16) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(totalReps)")
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .contentTransition(.numericText())
                                    Text("Total Reps")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // MARK: - Series Log
                        if isActive || !setLog.isEmpty {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("SERIES")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .tracking(1.5)
                                    Spacer()
                                    Text("\(setLog.count)")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.black)
                                        .foregroundStyle(.primary)
                                        .contentTransition(.numericText())
                                }
                                
                                if !setLog.isEmpty {
                                    VStack(spacing: 8) {
                                        ForEach(Array(setLog.enumerated().reversed()), id: \.offset) { index, reps in
                                            HStack {
                                                Text("Set \(index + 1)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.primary)
                                                
                                                Spacer()
                                                
                                                Text("\(reps) reps")
                                                    .font(.system(.subheadline, design: .rounded))
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.orange)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.orange.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                    }
                                } else {
                                    Text("Complete a set and add your reps above")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.5), lineWidth: 1)
                            )
                            .offset(y: isVisible ? 0 : 20)
                            .opacity(isVisible ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                timeElapsed += 1
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func addSet() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            setLog.append(selectedReps)
        }
    }
    
    private func finishSession() {
        appState.endTraining(
            reps: totalReps,
            sets: setLog.count,
            duration: timeElapsed,
            totalDuration: timeElapsed,
            videoURL: nil
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

#Preview {
    ManualTrainingView()
        .environmentObject(AppState())
}
