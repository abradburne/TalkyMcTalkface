import Foundation
import AVFoundation

/// Service for managing audio playback
/// Task 3.2: Create AudioPlayerService
@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    /// Published state
    @Published private(set) var isPlaying = false
    @Published private(set) var currentJobId: String?
    @Published private(set) var playbackProgress: Double = 0.0

    /// Internal audio player
    private var audioPlayer: AVAudioPlayer?

    /// Progress timer
    private var progressTimer: Timer?

    /// Callback for playback completion
    var onPlaybackComplete: (() -> Void)?

    override init() {
        super.init()
    }

    /// Cleanup resources
    func cleanup() {
        stop()
    }

    // MARK: - Public Interface

    /// Play audio from data
    /// Task 3.3: play(data: Data, jobId: String)
    func play(data: Data, jobId: String) {
        // Stop any current playback first
        stop()

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            if audioPlayer?.play() == true {
                isPlaying = true
                currentJobId = jobId
                playbackProgress = 0.0
                startProgressTracking()
            }
        } catch {
            print("[AudioPlayerService] Failed to play audio: \(error.localizedDescription)")
            isPlaying = false
            currentJobId = nil
        }
    }

    /// Pause current playback
    /// Task 3.3: pause()
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTracking()
    }

    /// Resume playback if paused
    func resume() {
        if audioPlayer?.play() == true {
            isPlaying = true
            startProgressTracking()
        }
    }

    /// Stop playback and reset
    /// Task 3.3: stop()
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentJobId = nil
        playbackProgress = 0.0
        stopProgressTracking()
    }

    /// Toggle play/pause
    /// Task 3.3: togglePlayPause()
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if audioPlayer != nil {
            resume()
        }
    }

    /// Check if currently playing a specific job
    func isPlayingJob(_ jobId: String) -> Bool {
        return isPlaying && currentJobId == jobId
    }

    // MARK: - Progress Tracking

    private func startProgressTracking() {
        stopProgressTracking()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTracking() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player = audioPlayer, player.duration > 0 else {
            playbackProgress = 0.0
            return
        }

        playbackProgress = player.currentTime / player.duration
    }
}

// MARK: - AVAudioPlayerDelegate

/// Task 3.4: Add playback delegate handling
extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentJobId = nil
            playbackProgress = 0.0
            stopProgressTracking()
            onPlaybackComplete?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("[AudioPlayerService] Decode error: \(error?.localizedDescription ?? "unknown")")
            isPlaying = false
            currentJobId = nil
            stopProgressTracking()
        }
    }
}
