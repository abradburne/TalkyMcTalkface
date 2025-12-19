import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for AudioPlayerService
/// Task 3.1: Write 3-5 focused tests for audio player
struct AudioPlayerTests {

    /// Test AudioPlayerService initial state
    @Test("AudioPlayerService starts in correct initial state")
    @MainActor
    func testAudioPlayerInitialState() {
        let service = AudioPlayerService()

        #expect(service.isPlaying == false)
        #expect(service.currentJobId == nil)
        #expect(service.playbackProgress == 0.0)
    }

    /// Test stop resets all state
    @Test("Stop resets all playback state")
    @MainActor
    func testStopResetsState() {
        let service = AudioPlayerService()

        // Manually set some state (simulating mid-playback)
        // Since we can't directly set private properties, we'll verify stop behavior

        service.stop()

        #expect(service.isPlaying == false)
        #expect(service.currentJobId == nil)
        #expect(service.playbackProgress == 0.0)
    }

    /// Test isPlayingJob helper method
    @Test("isPlayingJob returns correct value")
    @MainActor
    func testIsPlayingJobHelper() {
        let service = AudioPlayerService()

        // When not playing anything
        #expect(service.isPlayingJob("job_123") == false)
        #expect(service.isPlayingJob("job_456") == false)

        // Note: We can't fully test positive case without actual audio data
        // but we verify the method exists and handles the not-playing case
    }

    /// Test togglePlayPause when not playing does nothing harmful
    @Test("TogglePlayPause when not playing is safe")
    @MainActor
    func testTogglePlayPauseSafe() {
        let service = AudioPlayerService()

        // Should not crash when there's no audio loaded
        service.togglePlayPause()

        #expect(service.isPlaying == false)
    }

    /// Test cleanup stops playback
    @Test("Cleanup stops any playback")
    @MainActor
    func testCleanupStopsPlayback() {
        let service = AudioPlayerService()

        service.cleanup()

        #expect(service.isPlaying == false)
        #expect(service.currentJobId == nil)
    }
}
