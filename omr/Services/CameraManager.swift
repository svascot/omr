import AVFoundation
import Foundation
import Combine
import UIKit

class CameraManager: NSObject, ObservableObject {
    enum CameraStatus: Equatable {
        case unconfigured
        case configured
        case recording
        case paused
        case error(String)
    }
    
    @Published var status: CameraStatus = .unconfigured
    @Published var session: AVCaptureSession = AVCaptureSession()
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.omr.sessionQueue")
    private let videoQueue = DispatchQueue(label: "com.omr.videoQueue")
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var adapter: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isRecording = false
    private var isPaused = false
    private var isResuming = false
    private var currentVideoURL: URL?
    
    // Time base management for pausing
    private var startTime: CMTime?
    private var timeOffset: CMTime = .zero
    private var lastFrameTime: CMTime = .zero
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            
            // Front Camera Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoDeviceInput) else {
                DispatchQueue.main.async { self.status = .error("Failed to access front camera") }
                return
            }
            self.session.addInput(videoDeviceInput)
            
            // Video Output
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = false
                
                // Set orientation for portrait
                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = true // Digital Mirror
                    }
                }
            } else {
                DispatchQueue.main.async { self.status = .error("Failed to add video output") }
                return
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            DispatchQueue.main.async { self.status = .configured }
        }
    }
    
    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.status != .recording else { return }
            
            let fileName = "OMR_Session_\(UUID().uuidString).mov"
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            self.currentVideoURL = outputURL
            
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
                
                if writer.canAdd(input) {
                    writer.add(input)
                }
                
                self.assetWriter = writer
                self.assetWriterInput = input
                self.startTime = nil
                self.timeOffset = .zero
                self.isRecording = true
                self.isPaused = false
                
                DispatchQueue.main.async { self.status = .recording }
            } catch {
                DispatchQueue.main.async { self.status = .error("Failed to start writer: \(error.localizedDescription)") }
            }
        }
    }
    
    func pauseRecording() {
        isPaused = true
        DispatchQueue.main.async { self.status = .paused }
    }
    
    func resumeRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // Capture the current clock time to calculate the gap
            let currentTime = CMClockGetTime(CMClockGetHostTimeClock())
            if self.lastFrameTime.value > 0 {
                // Gap = Current Time - lastFrameTime
                // This is a simplification; in a real capture, we'd use the next buffer's timestamp.
                // For now, setting a flag to calculate offset on the next frame.
                self.isResuming = true
            }
            self.isPaused = false
            DispatchQueue.main.async { self.status = .recording }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            
            guard let writer = self.assetWriter, writer.status == .writing else {
                completion(nil)
                return
            }
            
            self.assetWriterInput?.markAsFinished()
            writer.finishWriting {
                let url = self.currentVideoURL
                self.assetWriter = nil
                self.assetWriterInput = nil
                DispatchQueue.main.async { 
                    self.status = .configured
                    completion(url)
                }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if isPaused {
            if lastFrameTime.value > 0 {
                // Keep track of how long we've been paused
                // We'll calculate the final offset once we resume
            }
            return
        }
        
        guard isRecording, let writer = assetWriter, let input = assetWriterInput else { return }
        
        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            startTime = timestamp
            lastFrameTime = timestamp
            return
        }
        
        guard input.isReadyForMoreMediaData else { return }
        
        // Calculate offset if we just resumed
        if isResuming {
            let gap = CMTimeSubtract(timestamp, lastFrameTime)
            timeOffset = CMTimeAdd(timeOffset, gap)
            isResuming = false
        }
        
        // Apply time offset to the current frame
        var adjustedBuffer: CMSampleBuffer?
        
        // If we have a time offset, apply it
        if timeOffset.value > 0 {
            var count: CMItemCount = 0
            CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, timingInfoArrayOut: nil, timingInfoCountOut: &count)
            var info = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: .zero, presentationTimeStamp: .zero, decodeTimeStamp: .zero), count: count)
            CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, timingInfoArrayOut: &info, timingInfoCountOut: &count)
            
            for i in 0..<count {
                info[i].presentationTimeStamp = CMTimeSubtract(info[i].presentationTimeStamp, timeOffset)
                info[i].decodeTimeStamp = info[i].decodeTimeStamp == .invalid ? .invalid : CMTimeSubtract(info[i].decodeTimeStamp, timeOffset)
            }
            
            CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: count, sampleTimingArray: info, sampleBufferOut: &adjustedBuffer)
        } else {
            adjustedBuffer = sampleBuffer
        }
        
        if let bufferToWrite = adjustedBuffer {
            input.append(bufferToWrite)
            lastFrameTime = CMSampleBufferGetPresentationTimeStamp(bufferToWrite)
        }
    }
}
