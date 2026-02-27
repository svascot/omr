import AVFoundation
import Foundation
import Combine
import UIKit
import Vision
import CoreGraphics
import CoreVideo

@MainActor
class CameraManager: NSObject, ObservableObject {
    enum CameraStatus: Equatable {
        case unconfigured
        case configured
        case recording
        case paused
        case error(String)
    }
    
    enum GestureAction {
        case peace // Start/Pause
        case wave  // Finish
    }
    
    @Published var status: CameraStatus = .unconfigured
    @Published var detectedGesture: GestureAction?
    
    struct OverlayState: Sendable {
        var reps: Int = 0
        var seriesTime: TimeInterval = 0
        var totalTime: TimeInterval = 0
    }
    private nonisolated(unsafe) var overlayState = OverlayState()
    private nonisolated(unsafe) var seriesTimeForOverlay: TimeInterval = 0
    private nonisolated(unsafe) var totalTimeForOverlay: TimeInterval = 0
    
    nonisolated let movementService = MovementService()
    
    nonisolated(unsafe) let session: AVCaptureSession = AVCaptureSession()
    
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.omr.sessionQueue")
    private let videoQueue = DispatchQueue(label: "com.omr.videoQueue")
    
    // Vision Properties
    nonisolated(unsafe) private let handPoseRequest = VNDetectHumanHandPoseRequest()
    nonisolated(unsafe) private var lastGestureTime: Date = .distantPast
    private let gestureDebounceInterval: TimeInterval = 1.5
    
    // Wave detection state
    private nonisolated(unsafe) var handXHistory: [CGFloat] = []
    private nonisolated(unsafe) var lastPalmDetectionTime: Date = .distantPast
    private let waveThreshold: CGFloat = 0.12 // Slightly lowered for better sensitivity
    private let historyLimit = 15
    private let historyTimeout: TimeInterval = 0.8 // Clear history if no palm for 0.8s
    
    // Engine properties: Managed STRICTLY on sessionQueue/videoQueue
    nonisolated(unsafe) private var assetWriter: AVAssetWriter?
    nonisolated(unsafe) private var assetWriterInput: AVAssetWriterInput?
    nonisolated(unsafe) private var isRecordingAtEngine = false
    nonisolated(unsafe) private var isPausedAtEngine = false
    nonisolated(unsafe) private var isResumingAtEngine = false
    nonisolated(unsafe) private var currentVideoURLAtEngine: URL?
    
    // Time base management
    nonisolated(unsafe) private var startTimeAtEngine: CMTime?
    nonisolated(unsafe) private var timeOffsetAtEngine: CMTime = .zero
    nonisolated(unsafe) private var lastFrameTimeAtEngine: CMTime = .zero
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                self.updateStatus(.error("Failed to access front camera"))
                return
            }
            self.session.addInput(videoDeviceInput)
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                
                // Force 32BGRA for easier drawing/overlays
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = false
                
                if let connection = self.videoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                    } else {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                    }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true
                    }
                }
            } else {
                self.updateStatus(.error("Failed to add video output"))
                return
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            self.updateStatus(.configured)
        }
    }
    
    nonisolated private func updateStatus(_ newStatus: CameraStatus) {
        Task { @MainActor [weak self] in
            self?.status = newStatus
        }
    }
    
    func startRecording() {
        print("DEBUG: Action - START RECORDING")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Re-check session status
            if !self.session.isRunning {
                self.session.startRunning()
            }
            
            let fileName = "OMR_Session_\(UUID().uuidString).mov"
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            self.currentVideoURLAtEngine = outputURL
            
            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
                
                let writer = try AVAssetWriter(url: outputURL, fileType: .mov)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 720,
                    AVVideoHeightKey: 1280
                ]
                
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                input.expectsMediaDataInRealTime = true
                if writer.canAdd(input) { writer.add(input) }
                
                self.assetWriter = writer
                self.assetWriterInput = input
                self.startTimeAtEngine = nil
                self.timeOffsetAtEngine = .zero
                self.lastFrameTimeAtEngine = .zero // Explicitly reset this
                self.isRecordingAtEngine = true
                self.isPausedAtEngine = false
                self.isResumingAtEngine = false // Ensure resume flag is clear
                
                self.movementService.resetCounter()
                self.seriesTimeForOverlay = 0
                self.totalTimeForOverlay = 0
                
                self.updateStatus(.recording)
            } catch {
                print("DEBUG: AVAssetWriter error: \(error.localizedDescription)")
                self.updateStatus(.error("Failed to start writer: \(error.localizedDescription)"))
            }
        }
    }
    
    func pauseRecording() {
        print("DEBUG: Action - PAUSE RECORDING")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isPausedAtEngine = true
            self.updateStatus(.paused)
        }
    }
    
    func resumeRecording() {
        print("DEBUG: Action - RESUME RECORDING")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.lastFrameTimeAtEngine.value > 0 {
                self.isResumingAtEngine = true
            }
            self.isPausedAtEngine = false
            self.updateStatus(.recording)
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("DEBUG: Action - STOP/FINISH RECORDING")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Capture state before resetting
            let wasRecording = self.isRecordingAtEngine
            self.isRecordingAtEngine = false
            
            guard let writer = self.assetWriter, let input = self.assetWriterInput else {
                print("DEBUG: No asset writer or input found upon stop. Recording was active: \(wasRecording)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("DEBUG: Finalizing recording. Status: \(writer.status.rawValue), Paused: \(self.isPausedAtEngine)")
            
            // If the writer is currently writing or even if it's in a state that can be finished
            if writer.status == .writing {
                input.markAsFinished()
                writer.finishWriting {
                    let url = self.currentVideoURLAtEngine
                    if writer.status == .failed {
                        print("DEBUG: Writer failed during finishWriting: \(writer.error?.localizedDescription ?? "unknown")")
                        DispatchQueue.main.async { completion(nil) }
                    } else {
                        print("DEBUG: Recording finalized successfully at: \(url?.path ?? "unknown")")
                        DispatchQueue.main.async { completion(url) }
                    }
                    
                    self.assetWriter = nil
                    self.assetWriterInput = nil
                    self.updateStatus(.configured)
                }
            } else {
                print("DEBUG: Cannot finish writing. Writer status is \(writer.status.rawValue). Error: \(writer.error?.localizedDescription ?? "none")")
                // Cleanup regardless
                self.assetWriter = nil
                self.assetWriterInput = nil
                self.updateStatus(.configured)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Method for UI to sync state for overlays
    nonisolated private func syncOverlayState(reps: Int, seriesTime: TimeInterval, totalTime: TimeInterval) {
        overlayState = OverlayState(reps: reps, seriesTime: seriesTime, totalTime: totalTime)
    }
    
    // Method for UI to update durations
    func updateOverlayTimers(series: TimeInterval, total: TimeInterval) {
        seriesTimeForOverlay = series
        totalTimeForOverlay = total
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Hand Gesture Detection - Always active
        detectGestures(in: sampleBuffer)
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Read engine state safely on videoQueue
        guard isRecordingAtEngine, let writer = assetWriter, let input = assetWriterInput else { return }
        
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            lastFrameTimeAtEngine = timestamp
            return
        }
        
        // Method for UI to sync state for overlays
        syncOverlayState(reps: movementService.internalRepCount, seriesTime: seriesTimeForOverlay, totalTime: totalTimeForOverlay)
        
        guard input.isReadyForMoreMediaData else { return }
        
        if isPausedAtEngine { return } // Do not append frames if paused
        
        if isResumingAtEngine {
            let gap = CMTimeSubtract(timestamp, lastFrameTimeAtEngine)
            timeOffsetAtEngine = CMTimeAdd(timeOffsetAtEngine, gap)
            isResumingAtEngine = false
        }
        
        var adjustedBuffer: CMSampleBuffer?
        if timeOffsetAtEngine.value > 0 {
            var count: CMItemCount = 0
            CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
            var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: .zero, presentationTimeStamp: .zero, decodeTimeStamp: .zero), count: count)
            CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &info, entriesNeededOut: &count)
            
            for i in 0..<count {
                info[i].presentationTimeStamp = CMTimeSubtract(info[i].presentationTimeStamp, timeOffsetAtEngine)
                if info[i].decodeTimeStamp != .invalid {
                    info[i].decodeTimeStamp = CMTimeSubtract(info[i].decodeTimeStamp, timeOffsetAtEngine)
                }
            }
            CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: info, sampleBufferOut: &adjustedBuffer)
        } else {
            adjustedBuffer = sampleBuffer
        }
        
        if let bufferToWrite = adjustedBuffer {
            // Apply overlays before writing
            if let pixelBuffer = CMSampleBufferGetImageBuffer(bufferToWrite) {
                addOverlays(to: pixelBuffer)
            }
            input.append(bufferToWrite)
            lastFrameTimeAtEngine = CMSampleBufferGetPresentationTimeStamp(bufferToWrite)
        }
        
        // Rep Counting - Only when recording and NOT paused
        movementService.processFrame(sampleBuffer)
    }
    
    nonisolated private func detectGestures(in sampleBuffer: CMSampleBuffer) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observations = handPoseRequest.results, !observations.isEmpty else { return }
            
            for observation in observations {
                // Get points for fingers
                guard let thumbPoints = try? observation.recognizedPoints(.thumb),
                      let indexPoints = try? observation.recognizedPoints(.indexFinger),
                      let middlePoints = try? observation.recognizedPoints(.middleFinger),
                      let ringPoints = try? observation.recognizedPoints(.ringFinger),
                      let littlePoints = try? observation.recognizedPoints(.littleFinger) else { continue }
                
                // Extract tip points
                guard let thumbTip = thumbPoints[.thumbTip],
                      let indexTip = indexPoints[.indexTip],
                      let middleTip = middlePoints[.middleTip],
                      let ringTip = ringPoints[.ringTip],
                      let littleTip = littlePoints[.littleTip] else { continue }
                
                // Basic gesture logic: Compare tip positions for "extended" fingers
                // Note: Vision coordinates are normalized (0-1). .up orientation means 1.0 is top.
                
                let isThumbExtended = thumbTip.confidence > 0.7 && thumbTip.location.y > (thumbPoints[.thumbIP]?.location.y ?? 0)
                let isIndexExtended = indexTip.confidence > 0.7 && indexTip.location.y > (indexPoints[.indexPIP]?.location.y ?? 0)
                let isMiddleExtended = middleTip.confidence > 0.7 && middleTip.location.y > (middlePoints[.middlePIP]?.location.y ?? 0)
                let isRingExtended = ringTip.confidence > 0.7 && ringTip.location.y > (ringPoints[.ringPIP]?.location.y ?? 0)
                let isLittleExtended = littleTip.confidence > 0.7 && littleTip.location.y > (littlePoints[.littlePIP]?.location.y ?? 0)
                
                // Peace Sign: Index and Middle extended, others folded
                if isIndexExtended && isMiddleExtended && !isRingExtended && !isLittleExtended && !isThumbExtended {
                    print("DEBUG: Vision identified PEACE sign")
                    triggerGesture(.peace)
                    return
                }
                
                // Hand Wave Detection: Focus on 4 main fingers, thumb is often unreliable
                let isOpenPalm = isIndexExtended && isMiddleExtended && isRingExtended && isLittleExtended
                
                if isOpenPalm {
                    let now = Date()
                    // Clear history if there's a big time gap (detection lost for too long)
                    if now.timeIntervalSince(lastPalmDetectionTime) > historyTimeout {
                        handXHistory.removeAll()
                    }
                    lastPalmDetectionTime = now
                    
                    let currentX = middleTip.location.x
                    handXHistory.append(currentX)
                    if handXHistory.count > historyLimit {
                        handXHistory.removeFirst()
                    }
                    
                    if handXHistory.count >= historyLimit {
                        let minX = handXHistory.min() ?? 0
                        let maxX = handXHistory.max() ?? 0
                        let displacement = maxX - minX
                        
                        if displacement > waveThreshold {
                            print("DEBUG: Vision identified HAND WAVE (displacement: \(displacement))")
                            triggerGesture(.wave)
                            handXHistory.removeAll() // Reset after trigger
                            return
                        }
                    }
                } else {
                    // Do NOT clear history immediately on flicker (relaxed approach)
                    // It will timeout via historyTimeout if the hand is truly gone.
                }
            }
        } catch {
            print("DEBUG: Vision error: \(error.localizedDescription)")
        }
    }
    
    nonisolated private func triggerGesture(_ gesture: GestureAction) {
        // Debounce on videoQueue side to avoid flooding
        let now = Date()
        guard now.timeIntervalSince(lastGestureTime) > gestureDebounceInterval else { return }
        lastGestureTime = now
        
        Task { @MainActor [weak self] in
            print("DEBUG: Detected gesture: \(gesture)")
            self?.detectedGesture = gesture
            // Reset after a short delay so it can be re-triggered if needed
            // However, the debounce handles the frequency.
        }
    }
    
    nonisolated private func addOverlays(to pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: baseAddress,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return
        }
        
        // Flip coordinates for UIKit drawing
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        
        let state = overlayState
        let reps = state.reps
        let seriesStr = formatTime(state.seriesTime)
        let totalStr = formatTime(state.totalTime)
        
        // 1. Rep Counter Card (Top Left)
        let repCardRect = CGRect(x: 40, y: 60, width: 160, height: 160)
        drawGlassCard(in: repCardRect, context: context, cornerRadius: 28)
        
        // REPS Label - Centered at the top of the card
        drawCenteredText("REPS", in: CGRect(x: repCardRect.minX, y: repCardRect.minY + 24, width: repCardRect.width, height: 20), size: 12, weight: .bold, tracking: 1.5, color: .white.withAlphaComponent(0.8), context: context)
        
        // Rep Count Value - Centered in the remaining card space
        drawCenteredRoundedText("\(reps)", in: CGRect(x: repCardRect.minX, y: repCardRect.minY + 44, width: repCardRect.width, height: 100), size: 64, weight: .black, context: context)
        
        // 2. Timer Cards (Top Right)
        let timerCardWidth: CGFloat = 200
        let timerCardHeight: CGFloat = 44
        let timerGap: CGFloat = 12
        let rightMargin: CGFloat = 40
        let topMargin: CGFloat = 60
        
        // Series Time Card
        let seriesCardRect = CGRect(x: width - timerCardWidth - rightMargin, y: topMargin, width: timerCardWidth, height: timerCardHeight)
        drawGlassCard(in: seriesCardRect, context: context, cornerRadius: timerCardHeight / 2)
        
        drawText("SERIES", at: CGPoint(x: seriesCardRect.minX + 16, y: seriesCardRect.midY - 6), size: 10, weight: .black, tracking: 1.0, color: .white.withAlphaComponent(0.6), context: context)
        drawMonospacedText(seriesStr, at: CGPoint(x: seriesCardRect.maxX - 70, y: seriesCardRect.midY - 10), size: 17, weight: .bold, context: context)
        
        // Total Time Card
        let totalCardRect = CGRect(x: width - timerCardWidth - rightMargin, y: topMargin + timerCardHeight + timerGap, width: timerCardWidth, height: timerCardHeight)
        drawGlassCard(in: totalCardRect, context: context, cornerRadius: timerCardHeight / 2, opacity: 0.3)
        
        drawText("TOTAL", at: CGPoint(x: totalCardRect.minX + 16, y: totalCardRect.midY - 6), size: 10, weight: .black, tracking: 1.0, color: .white.withAlphaComponent(0.6), context: context)
        drawMonospacedText(totalStr, at: CGPoint(x: totalCardRect.maxX - 70, y: totalCardRect.midY - 10), size: 17, weight: .bold, color: .white.withAlphaComponent(0.5), context: context)
    }
    
    nonisolated private func drawGlassCard(in rect: CGRect, context: CGContext, cornerRadius: CGFloat, opacity: CGFloat = 0.4) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        
        context.saveGState()
        
        // Fill: Simulating ultraThinMaterial with a translucent white/grey
        context.setFillColor(UIColor.black.withAlphaComponent(opacity).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Stroke: White border with low opacity
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1.5)
        context.addPath(path.cgPath)
        context.strokePath()
        
        context.restoreGState()
    }
    
    nonisolated private func drawCenteredText(_ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular, tracking: CGFloat = 0, color: UIColor = .white, context: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        
        let string = NSAttributedString(string: text, attributes: attributes)
        
        // Vertically center text in the rect
        let textSize = string.size()
        let textRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - textSize.height) / 2,
            width: rect.width,
            height: textSize.height
        )
        
        string.draw(in: textRect)
    }
    
    nonisolated private func drawCenteredRoundedText(_ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular, context: CGContext) {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let roundedFont: UIFont
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            roundedFont = UIFont(descriptor: descriptor, size: size)
        } else {
            roundedFont = systemFont
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: roundedFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        
        // Vertically center text in the rect
        let textSize = string.size()
        let textRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height - textSize.height) / 2,
            width: rect.width,
            height: textSize.height
        )
        
        string.draw(in: textRect)
    }
    
    nonisolated private func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight = .regular, tracking: CGFloat = 0, color: UIColor = .white, context: CGContext) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: point)
    }
    
    nonisolated private func drawMonospacedText(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .white, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: point)
    }
    
    nonisolated private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
