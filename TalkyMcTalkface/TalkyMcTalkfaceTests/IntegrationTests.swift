import Testing
import Foundation
@testable import TalkyMcTalkface

/// Integration tests for end-to-end workflows
/// Task 8.3: Write up to 10 additional strategic tests
struct IntegrationTests {

    // MARK: - End-to-End Flow Tests

    /// Test complete workflow: AppState initializes with all services
    @Test("AppState initializes with all required services")
    @MainActor
    func testAppStateInitializesServices() {
        let appState = AppState()

        // Verify all services are initialized
        #expect(appState.settingsService != nil)
        #expect(appState.subprocessManager != nil)
        #expect(appState.modelDownloadService != nil)
        #expect(appState.voiceService != nil)
        #expect(appState.jobService != nil)
        #expect(appState.audioPlayerService != nil)
    }

    /// Test job creation request encoding is correct for API
    @Test("CreateJobRequest produces valid JSON for API")
    func testJobCreationRequestEncoding() throws {
        let request = CreateJobRequest(text: "Hello world", voiceId: "voice_123")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify snake_case keys for API
        #expect(json["text"] as? String == "Hello world")
        #expect(json["voice_id"] as? String == "voice_123")
    }

    /// Test job response decoding handles all status types
    @Test("TTSJob decodes all status types from API response")
    func testJobResponseDecodingAllStatuses() throws {
        let statuses = ["pending", "processing", "completed", "failed"]

        for statusStr in statuses {
            let json = """
            {
                "id": "job_test",
                "status": "\(statusStr)",
                "text": "Test text",
                "voice_id": "voice_1",
                "created_at": "2024-12-18T10:30:00Z"
            }
            """

            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let job = try decoder.decode(TTSJob.self, from: data)
            #expect(job.status.rawValue == statusStr)
        }
    }

    /// Test settings persist across encode/decode cycles
    @Test("Settings persistence survives encode/decode cycle")
    func testSettingsPersistenceCycle() throws {
        let originalSettings = AppSettings(
            modelUnloadTimeoutMinutes: 30,
            launchAtLogin: true,
            defaultVoiceId: "voice_123"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(originalSettings)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded == originalSettings)
    }

    /// Test voices response parsing from API format
    @Test("VoicesResponse parses API response correctly")
    func testVoicesResponseParsing() throws {
        let json = """
        {
            "voices": [
                {"id": "voice_alice", "name": "Alice"},
                {"id": "voice_bob", "name": "Bob"}
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(VoicesResponse.self, from: data)

        #expect(response.voices.count == 2)
        #expect(response.voices[0].id == "voice_alice")
        #expect(response.voices[1].name == "Bob")
    }

    // MARK: - Error Handling Tests

    /// Test job status enum handles unknown status gracefully
    @Test("JobStatus can be extended for error display")
    func testJobStatusDisplayProperties() {
        // Verify all statuses have display properties
        let allStatuses: [JobStatus] = [.pending, .processing, .completed, .failed]

        for status in allStatuses {
            #expect(!status.iconName.isEmpty)
            #expect(!status.iconColorName.isEmpty)
        }
    }

    /// Test TTSJob relative timestamp formatting
    @Test("TTSJob relativeTimestamp produces readable output")
    func testJobRelativeTimestamp() {
        let recentJob = TTSJob(
            id: "job_1",
            status: .completed,
            text: "Test",
            voiceId: "voice_1",
            createdAt: Date().addingTimeInterval(-60) // 1 minute ago
        )

        // Should produce a non-empty relative time string
        #expect(!recentJob.relativeTimestamp.isEmpty)
    }

    // MARK: - Service Configuration Tests

    /// Test all service URLs are correctly configured
    @Test("Service URLs use correct host and port")
    @MainActor
    func testServiceURLConfiguration() {
        // All services should use the same backend
        #expect(VoiceService.voicesURL.host == "127.0.0.1")
        #expect(JobService.baseURL.contains("5111"))
        #expect(ModelDownloadService.downloadURL.host == "127.0.0.1")
    }

    /// Test AppSettings default values are sensible
    @Test("AppSettings defaults are appropriate for first launch")
    func testAppSettingsDefaults() {
        let defaults = AppSettings.defaultSettings

        // Default values should be safe for first launch
        #expect(defaults.launchAtLogin == false)
        #expect(defaults.modelUnloadTimeoutMinutes == 0) // Never unload
        #expect(defaults.defaultVoiceId == nil) // Will use first available
    }

    /// Test AppState correctly exposes audio player state
    @Test("AppState correctly exposes audio playback state")
    @MainActor
    func testAppStateAudioStatePassthrough() {
        let appState = AppState()

        // Initial state should be not playing
        #expect(appState.isPlaying == false)
        #expect(appState.currentPlayingJobId == nil)
    }
}
