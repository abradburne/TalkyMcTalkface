import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for VoiceService and JobService
/// Task 2.1: Write 4-6 focused tests for API services
struct APIServiceTests {

    // MARK: - VoiceService Tests

    /// Test VoiceService URL configuration
    @Test("VoiceService voices URL is correctly configured")
    @MainActor
    func testVoiceServiceURLConfiguration() {
        #expect(VoiceService.voicesURL.absoluteString == "http://127.0.0.1:5111/voices")
    }

    /// Test VoiceService initial state
    @Test("VoiceService starts in correct initial state")
    @MainActor
    func testVoiceServiceInitialState() {
        let service = VoiceService()

        #expect(service.voices.isEmpty)
        #expect(service.isLoading == false)
        #expect(service.errorMessage == nil)
    }

    // MARK: - JobService Tests

    /// Test JobService URL configuration
    @Test("JobService URLs are correctly configured")
    @MainActor
    func testJobServiceURLConfiguration() {
        #expect(JobService.jobsURL.absoluteString == "http://127.0.0.1:5111/jobs")
        #expect(JobService.baseURL == "http://127.0.0.1:5111")
    }

    /// Test JobService initial state
    @Test("JobService starts in correct initial state")
    @MainActor
    func testJobServiceInitialState() {
        let service = JobService()

        #expect(service.jobs.isEmpty)
        #expect(service.isLoading == false)
        #expect(service.errorMessage == nil)
    }

    /// Test CreateJobRequest encoding sends correct body
    @Test("CreateJobRequest encodes with snake_case keys")
    func testCreateJobRequestEncoding() throws {
        let request = CreateJobRequest(text: "Hello world", voiceId: "voice_123")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        // Decode to verify structure
        let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(decoded["text"] as? String == "Hello world")
        #expect(decoded["voice_id"] as? String == "voice_123")
        // Ensure camelCase key is not present
        #expect(decoded["voiceId"] == nil)
    }

    /// Test jobs are sorted by creation date descending
    @Test("Jobs list sorts by createdAt descending")
    func testJobsSortOrder() throws {
        let json = """
        {
            "jobs": [
                {"id": "job_1", "status": "completed", "text": "First", "voice_id": "v1", "created_at": "2024-12-18T10:00:00Z"},
                {"id": "job_3", "status": "completed", "text": "Third", "voice_id": "v1", "created_at": "2024-12-18T12:00:00Z"},
                {"id": "job_2", "status": "completed", "text": "Second", "voice_id": "v1", "created_at": "2024-12-18T11:00:00Z"}
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(JobsListResponse.self, from: data)

        // Sort as the service does
        let sortedJobs = response.jobs.sorted { $0.createdAt > $1.createdAt }

        #expect(sortedJobs[0].id == "job_3") // Most recent
        #expect(sortedJobs[1].id == "job_2")
        #expect(sortedJobs[2].id == "job_1") // Oldest
    }
}
