import Foundation
import Combine
import MediaPlayer
import AVFoundation

@MainActor
class AirPodsService: ObservableObject {
    /// Toggled each time an AirPod tap is detected. Observe with `.onChange`.
    @Published var tapDetected: Bool = false
    
    private var isActive = false
    
    // Engine for silent audio to keep Now Playing active
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    
    // MARK: - Lifecycle
    
    /// Configures audio session and registers for remote command center events.
    func start() {
        guard !isActive else { return }
        isActive = true
        
        print("DEBUG: AirPodsService starting...")
        
        configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        setupRemoteCommandCenter()
        setupNowPlayingInfo()
        playSilentAudio()
        
        print("DEBUG: AirPodsService started — actively listening for taps")
    }
    
    /// Removes remote command handlers and deactivates audio session.
    func stop() {
        guard isActive else { return }
        isActive = false
        
        stopSilentAudio()
        UIApplication.shared.endReceivingRemoteControlEvents()
        
        tearDownRemoteCommandCenter()
        deactivateAudioSession()
        
        print("DEBUG: AirPodsService stopped")
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Critical: Category must be playback to receive remote events.
            // Removing .mixWithOthers briefly to see if it forces iOS to treat us as Now Playing.
            // If it pauses other apps, we might need to add it back + .duckOthers
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
            
            print("DEBUG: AVAudioSession successfully activated for playback")
        } catch {
            print("DEBUG: Failed to configure/activate AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("DEBUG: Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Silent Audio (Now Playing Hack)
    
    private func playSilentAudio() {
        audioEngine.attach(audioPlayerNode)
        
        // Standard format
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: format)
        
        do {
            try audioEngine.start()
            
            // Create 1 second of silent audio
            let frameCount = AVAudioFrameCount(format.sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            
            if let channelData = buffer.floatChannelData?[0] {
                for i in 0..<Int(frameCount) {
                    channelData[i] = 0.0
                }
            }
            
            // Loop silently infinitely
            audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            audioPlayerNode.play()
        } catch {
            print("DEBUG: Failed to start silent audio engine: \(error.localizedDescription)")
        }
    }
    
    private func stopSilentAudio() {
        audioPlayerNode.stop()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Single tap on AirPods fires togglePlayPauseCommand
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            print("DEBUG: MPRemoteCommandCenter received togglePlayPauseCommand!")
            Task { @MainActor [weak self] in
                self?.handleTap()
            }
            return .success
        }
        
        // Also handle explicit play/pause commands for broader compatibility
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            print("DEBUG: MPRemoteCommandCenter received playCommand!")
            Task { @MainActor [weak self] in
                self?.handleTap()
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            print("DEBUG: MPRemoteCommandCenter received pauseCommand!")
            Task { @MainActor [weak self] in
                self?.handleTap()
            }
            return .success
        }
        
        print("DEBUG: RemoteCommandCenter targets registered for play/pause/toggle")
    }
    
    private func tearDownRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
    }
    
    // MARK: - Now Playing Info
    
    private func setupNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "OMR Session"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "One More Rep"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double.greatestFiniteMagnitude
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("DEBUG: NowPlayingInfo set up")
    }
    
    // MARK: - Tap Handling
    
    private func handleTap() {
        print("DEBUG: \n==========================\nAIRPOD TAP DETECTED!\n==========================")
        tapDetected.toggle()
    }
}
