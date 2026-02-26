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
    private nonisolated(unsafe) var peakY: CGFloat = -1
    private nonisolated(unsafe) var valleyY: CGFloat = 2
    private let motionThreshold: CGFloat = 0.05 // Increased sensitivity (5% of screen height)
    
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
            
            // Try to get nose first (as requested for "head" tracking)
            var targetPoint: VNRecognizedPoint?
            if let nose = try? observation.recognizedPoint(.nose), nose.confidence > 0.5 {
                targetPoint = nose
            } else if let neck = try? observation.recognizedPoint(.neck), neck.confidence > 0.5 {
                // Fallback to neck for stability
                targetPoint = neck
            }
            
            guard let point = targetPoint else { return }
            let currentY = point.location.y
            
            // Initialization for first frame
            if peakY < 0 {
                peakY = currentY
                valleyY = currentY
                return
            }
            
            // State machine for robust rep counting using Peak-to-Valley logic
            switch currentState {
            case .up:
                // Track the highest point reached during the Up phase
                peakY = max(peakY, currentY)
                
                // If we drop significantly below the peak, transition to Down
                if currentY < peakY - motionThreshold {
                    currentState = .down
                    valleyY = currentY // Start tracking valley from here
                    print("DEBUG: Movement state -> DOWN (Peak: \(String(format: "%.2f", peakY)), Current: \(String(format: "%.2f", currentY)))")
                }
                
            case .down:
                // Track the lowest point reached during the Down phase
                valleyY = min(valleyY, currentY)
                
                // If we rise significantly above the valley, transition to Up and count a rep
                if currentY > valleyY + motionThreshold {
                    currentState = .up
                    peakY = currentY // Start tracking peak from here
                    
                    internalRepCount += 1
                    let newCount = internalRepCount
                    Task { @MainActor in
                        self.repCount = newCount
                        print("DEBUG: Rep counted! Total: \(self.repCount)")
                    }
                    print("DEBUG: Movement state -> UP (Valley: \(String(format: "%.2f", valleyY)), Current: \(String(format: "%.2f", currentY)))")
                }
            }
        } catch {
            print("DEBUG: Movement Vision error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func resetCounter() {
        internalRepCount = 0
        peakY = -1
        valleyY = 2
        Task { @MainActor in
            self.repCount = 0
            self.currentState = .up
            print("DEBUG: Movement counter reset")
        }
    }
}
