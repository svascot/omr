import Vision
import Foundation
import Combine

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
    private let absoluteMotionThreshold: CGFloat = 0.05 // 5% of screen height for absolute push-up/squat tracking
    private let relativeMotionThreshold: CGFloat = 0.15 // 15% distance change for pull-ups (arms are long)
    
    enum TrackingMode: Equatable, Sendable {
        case uninitialized
        case absolutePoint // Tracking raw Y coordinate of head
        case relativeDistance // Tracking distance between hands and head (Pull-ups)
    }
    private nonisolated(unsafe) var activeMode: TrackingMode = .uninitialized
    
    enum MovementState: Sendable {
        case up
        case down
    }
    private nonisolated(unsafe) var currentState: MovementState = .up
    
    nonisolated override init() {
        super.init()
    }
    
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyPoseRequest])
            guard let observation = bodyPoseRequest.results?.first else { return }
            
            // 1. Core Points
            var headPoint: VNRecognizedPoint?
            if let nose = try? observation.recognizedPoint(.nose), nose.confidence > 0.5 {
                headPoint = nose
            } else if let neck = try? observation.recognizedPoint(.neck), neck.confidence > 0.5 {
                headPoint = neck
            }
            guard let head = headPoint else { return }
            
            // 2. Try to find wrists for Pull-up mode
            var wristYAvg: CGFloat? = nil
            let leftWrist = try? observation.recognizedPoint(.leftWrist)
            let rightWrist = try? observation.recognizedPoint(.rightWrist)
            
            var validWrists = [CGFloat]()
            if let lw = leftWrist, lw.confidence > 0.3 { validWrists.append(lw.location.y) }
            if let rw = rightWrist, rw.confidence > 0.3 { validWrists.append(rw.location.y) }
            
            if !validWrists.isEmpty {
                wristYAvg = validWrists.reduce(0, +) / CGFloat(validWrists.count)
            }
            
            // 3. Determine the Current Value being tracked
            let currentValue: CGFloat
            let currentMode: TrackingMode
            
            if let wrists = wristYAvg {
                // RELATIVE MODE (Pull-ups)
                // Distance between head and wrists.
                // At dead hang, distance is MAX. At top of pull-up, distance is MIN.
                currentValue = abs(wrists - head.location.y)
                currentMode = .relativeDistance
            } else {
                // ABSOLUTE MODE (Push-ups, Squats)
                // Raw Y position of the head.
                currentValue = head.location.y
                currentMode = .absolutePoint
            }
            
            // 4. Initialization or Mode Switch
            if peakValue < 0 || activeMode != currentMode {
                peakValue = currentValue
                valleyValue = currentValue
                activeMode = currentMode
                // If we enter relative mode (arms visible), we start in "down" (dead hang) expecting a pull-up
                currentState = currentMode == .relativeDistance ? .down : .up
                print("DEBUG: Movement mode switched to \(currentMode)")
                return
            }
            
            let threshold = activeMode == .relativeDistance ? relativeMotionThreshold : absoluteMotionThreshold
            
            // 5. State machine for robust rep counting
            switch currentState {
            case .up:
                // Track the highest value reached during the Up phase
                // For relative (pull-up): high value = large distance = dead hang (which is actually down, see below)
                peakValue = max(peakValue, currentValue)
                
                // If value drops significantly below the peak, transition to Down
                // (For absolute: head dropped. For relative: distance decreased, so pulling up to the bar)
                if currentValue < peakValue - threshold {
                    currentState = .down
                    valleyValue = currentValue // Start tracking valley from here
                    print("DEBUG: Movement state -> DOWN (Peak: \(String(format: "%.2f", peakValue)), Current: \(String(format: "%.2f", currentValue)))")
                }
                
            case .down:
                // Track the lowest value reached during the Down phase
                // For relative (pull-up): low value = small distance = chin over bar
                valleyValue = min(valleyValue, currentValue)
                
                // If we rise significantly above the valley, transition to Up and count a rep
                // (For absolute: head rose. For relative: distance increased, dropping back to dead hang)
                if currentValue > valleyValue + threshold {
                    currentState = .up
                    peakValue = currentValue // Start tracking peak from here
                    
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
