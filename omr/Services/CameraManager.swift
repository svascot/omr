import AVFoundation
import Foundation
import Combine
import UIKit

@MainActor
class CameraManager: NSObject, ObservableObject {
    enum CameraStatus: Equatable {
        case unconfigured
        case configured
        case recording
        case paused
        case error(String)
    }
    
    @Published var status: CameraStatus = .unconfigured
    nonisolated(unsafe) let session: AVCaptureSession = AVCaptureSession()
    
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.omr.sessionQueue")
    private let videoQueue = DispatchQueue(label: "com.omr.videoQueue")
    
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
    
    private func updateStatus(_ newStatus: CameraStatus) {
        Task { @MainActor [weak self] in
            self?.status = newStatus
        }
    }
    
    func startRecording() {
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
                self.isRecordingAtEngine = true
                self.isPausedAtEngine = false
                
                self.updateStatus(.recording)
            } catch {
                self.updateStatus(.error("Failed to start writer: \(error.localizedDescription)"))
            }
        }
    }
    
    func pauseRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isPausedAtEngine = true
            self.updateStatus(.paused)
        }
    }
    
    func resumeRecording() {
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
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isRecordingAtEngine = false
            
            guard let writer = self.assetWriter, writer.status == .writing else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.assetWriterInput?.markAsFinished()
            writer.finishWriting {
                let url = self.currentVideoURLAtEngine
                self.assetWriter = nil
                self.assetWriterInput = nil
                self.updateStatus(.configured)
                DispatchQueue.main.async { completion(url) }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Read engine state safely on videoQueue (or since they are only written on sessionQueue, 
        // we might want to sync but for performance we use the flags)
        guard isRecordingAtEngine, !isPausedAtEngine, let writer = assetWriter, let input = assetWriterInput else { return }
        
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            lastFrameTimeAtEngine = timestamp
            return
        }
        
        guard input.isReadyForMoreMediaData else { return }
        
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
            input.append(bufferToWrite)
            lastFrameTimeAtEngine = CMSampleBufferGetPresentationTimeStamp(bufferToWrite)
        }
    }
}
