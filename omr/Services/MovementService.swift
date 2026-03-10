import Vision
import Foundation
import Combine

enum TrackingMode: Sendable {
    case uninitialized
    case pushUp // Tracking absolute Y coordinate (working well as-is)
    case pullUp // Tracking elbow angle
    case squat  // Tracking knee angle
}

extension TrackingMode: Equatable {
    nonisolated static func == (lhs: TrackingMode, rhs: TrackingMode) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized): return true
        case (.pushUp, .pushUp): return true
        case (.pullUp, .pullUp): return true
        case (.squat, .squat): return true
        default: return false
        }
    }
}

enum MovementState: Sendable {
    case up
    case down
}

@MainActor
class MovementService: NSObject, ObservableObject, @unchecked Sendable {
    @Published var repCount: Int = 0
    @Published var isMoving: Bool = false
    
    // Thread-safe count for background service access (e.g. video overlays)
    private(set) nonisolated(unsafe) var internalRepCount: Int = 0
    
    private nonisolated(unsafe) var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    private nonisolated(unsafe) var peakValue: CGFloat = -1
    private nonisolated(unsafe) var valleyValue: CGFloat = 2
    
    // Thresholds
    private let pushUpThreshold: CGFloat = 0.05 // 5% of screen height
    private let angleThreshold: CGFloat = 30.0  // Degrees of joint bend required to trigger state changes
    
    private nonisolated(unsafe) var activeMode: TrackingMode = .uninitialized
    private nonisolated(unsafe) var currentState: MovementState = .up
    
    nonisolated override init() {
        super.init()
    }
    
    /// Calculates the angle in degrees between three points (e.g., Shoulder -> Elbow -> Wrist)
    nonisolated private func calculateAngle(first: CGPoint, mid: CGPoint, last: CGPoint) -> CGFloat {
        let radians = atan2(last.y - mid.y, last.x - mid.x) - atan2(first.y - mid.y, first.x - mid.x)
        var degrees = abs(radians * 180.0 / .pi)
        if degrees > 180.0 {
            degrees = 360.0 - degrees
        }
        return degrees
    }
    
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyPoseRequest])
            guard let observation = bodyPoseRequest.results?.first else { return }
            
            // 1. Extract Core Joints
            let nose = try? observation.recognizedPoint(.nose)
            let neck = try? observation.recognizedPoint(.neck)
            let head = (nose?.confidence ?? 0 > 0.5) ? nose : ((neck?.confidence ?? 0 > 0.5) ? neck : nil)
            guard let headPoint = head else { return }
            
            // Extract Joints for Angles (Confidence > 0.3)
            func getPoint(_ key: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                if let point = try? observation.recognizedPoint(key), point.confidence > 0.3 {
                    return point.location
                }
                return nil
            }
            
            let lShoulder = getPoint(.leftShoulder)
            let rShoulder = getPoint(.rightShoulder)
            let lElbow = getPoint(.leftElbow)
            let rElbow = getPoint(.rightElbow)
            let lWrist = getPoint(.leftWrist)
            let rWrist = getPoint(.rightWrist)
            
            let lHip = getPoint(.leftHip)
            let rHip = getPoint(.rightHip)
            let lKnee = getPoint(.leftKnee)
            let rKnee = getPoint(.rightKnee)
            let lAnkle = getPoint(.leftAnkle)
            let rAnkle = getPoint(.rightAnkle)
            
            // 2. Determine Tracking Mode & Current Value
            let currentValue: CGFloat
            let currentMode: TrackingMode
            
            // Heuristic 1: Pull-Ups (Wrists are above shoulders. In Vision, Y goes from 0 at bottom to 1 at top, so higher Y means higher physically on screen)
            let wristsY = [lWrist?.y, rWrist?.y].compactMap { $0 }
            let shouldersY = [lShoulder?.y, rShoulder?.y].compactMap { $0 }
            
            let avgWristY = wristsY.isEmpty ? nil : wristsY.reduce(0, +) / CGFloat(wristsY.count)
            let avgShoulderY = shouldersY.isEmpty ? nil : shouldersY.reduce(0, +) / CGFloat(shouldersY.count)
            
            // Heuristic 2: Squats (Standing mostly vertical, head is significantly higher than hips)
            let hipsY = [lHip?.y, rHip?.y].compactMap { $0 }
            let avgHipY = hipsY.isEmpty ? nil : hipsY.reduce(0, +) / CGFloat(hipsY.count)
            
            // Logic to select mode
            if let wY = avgWristY, let sY = avgShoulderY, wY > sY,
               let shoulder = lShoulder ?? rShoulder,
               let elbow = lElbow ?? rElbow,
               let wrist = lWrist ?? rWrist {
                // Determine it's a pull-up because arms are reached up
                currentMode = .pullUp
                // Calculate elbow angle
                currentValue = calculateAngle(first: shoulder, mid: elbow, last: wrist)
                
            } else if let hY = avgHipY, headPoint.location.y > hY + 0.2, // Head is comfortably above hips
                      let hip = lHip ?? rHip,
                      let knee = lKnee ?? rKnee,
                      let ankle = lAnkle ?? rAnkle {
                // Determine it's a squat/vertical movement
                currentMode = .squat
                // Calculate knee angle
                currentValue = calculateAngle(first: hip, mid: knee, last: ankle)
                
            } else {
                // Fallback to push-up / horizontal movement
                currentMode = .pushUp
                currentValue = headPoint.location.y
            }
            
            // 3. Initialization or Mode Switch
            if peakValue < 0 || activeMode != currentMode {
                peakValue = currentValue
                valleyValue = currentValue
                activeMode = currentMode
                // If angles, 180 is typically extended (straight leg/arm = up). 
                // Pushup Y, top of screen is 1.0. So higher is 'up'.
                currentState = .up
                print("DEBUG: Movement mode switched to \(currentMode)")
                return
            }
            
            // 4. Set Thresholds based on mode
            let threshold = (activeMode == .pushUp) ? pushUpThreshold : angleThreshold
            
            // 5. State machine for robust rep counting
            switch currentState {
            case .up:
                // Track highest angle (e.g. 180deg standing) or highest Y position (pushup top)
                peakValue = max(peakValue, currentValue)
                
                // If angle/Y drops significantly below peak, transition to Down
                // (Squat/Pullup: angle closes; Pushup: head drops)
                if currentValue < peakValue - threshold {
                    currentState = .down
                    valleyValue = currentValue
                    print("DEBUG: Movement state -> DOWN (Peak: \(String(format: "%.2f", peakValue)), Current: \(String(format: "%.2f", currentValue)))")
                }
                
            case .down:
                // Track lowest angle (e.g. 90deg squat bottom) or lowest Y position
                valleyValue = min(valleyValue, currentValue)
                
                // If value rises significantly above valley, transition to Up and count a rep
                if currentValue > valleyValue + threshold {
                    currentState = .up
                    peakValue = currentValue
                    
                    internalRepCount += 1
                    let newCount = internalRepCount
                    Task { @MainActor in
                        self.repCount = newCount
                        print("DEBUG: Rep counted! Total: \(self.repCount)")
                    }
                    print("DEBUG: Movement state -> UP (Valley: \(String(format: "%.2f", valleyValue)), Current: \(String(format: "%.2f", currentValue)))")
                }
            }
        } catch {
            print("DEBUG: Movement Vision error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func resetCounter() {
        internalRepCount = 0
        peakValue = -1
        valleyValue = 2
        activeMode = .uninitialized
        Task { @MainActor in
            self.repCount = 0
            self.currentState = .up
            print("DEBUG: Movement counter reset")
        }
    }
}
