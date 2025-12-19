import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for AppState extensions (voice, job, audio state)
/// Task 4.1: Write 4-6 focused tests for AppState extensions
struct AppStateExtensionTests {

    /// Test AppState initial voice state
    @Test("AppState has correct initial voice state")
    @MainActor
    func testInitialVoiceState() {
        let appState = AppState()

        #expect(appState.voices.isEmpty)
        #expect(appState.selectedVoiceId == nil)
        #expect(appState.isLoadingVoices == false)
    }

    /// Test AppState initial job state
    @Test("AppState has correct initial job state")
    @MainActor
    func testInitialJobState() {
        let appState = AppState()

        #expect(appState.jobs.isEmpty)
        #expect(appState.isGenerating == false)
        #expect(appState.currentInputText == "")
    }

    /// Test AppState initial audio state
    @Test("AppState has correct initial audio state")
    @MainActor
    func testInitialAudioState() {
        let appState = AppState()

        #expect(appState.isPlaying == false)
        #expect(appState.currentPlayingJobId == nil)
    }

    /// Test AppState services are initialized
    @Test("AppState initializes all services")
    @MainActor
    func testServicesInitialized() {
        let appState = AppState()

        // Verify services exist (not nil)
        #expect(appState.voiceService != nil)
        #expect(appState.jobService != nil)
        #expect(appState.audioPlayerService != nil)
    }

    /// Test updateDefaultVoice updates selectedVoiceId
    @Test("updateDefaultVoice sets selectedVoiceId")
    @MainActor
    func testUpdateDefaultVoice() {
        let appState = AppState()
        let testVoiceId = "test_voice_123"

        appState.updateDefaultVoice(id: testVoiceId)

        #expect(appState.selectedVoiceId == testVoiceId)
    }

    /// Test generateSpeech guards against empty input
    @Test("generateSpeech does nothing when input is empty")
    @MainActor
    func testGenerateSpeechEmptyInput() async {
        let appState = AppState()
        appState.currentInputText = ""
        appState.selectedVoiceId = "voice_1"

        await appState.generateSpeech()

        // Should not be generating since input is empty
        #expect(appState.isGenerating == false)
    }
}
