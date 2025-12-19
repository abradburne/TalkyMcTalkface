import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for Voice and TTSJob data models
/// Task 1.1: Write 4-6 focused tests for data model functionality
struct DataModelTests {

    // MARK: - Voice Model Tests

    /// Test Voice model decoding from JSON with snake_case conversion
    @Test("Voice model decodes from JSON correctly")
    func testVoiceDecoding() throws {
        let json = """
        {
            "id": "voice_123",
            "name": "Alice"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let voice = try decoder.decode(Voice.self, from: data)

        #expect(voice.id == "voice_123")
        #expect(voice.name == "Alice")
    }

    /// Test array decoding for voices list response
    @Test("VoicesResponse decodes array of voices correctly")
    func testVoicesResponseDecoding() throws {
        let json = """
        {
            "voices": [
                {"id": "voice_1", "name": "Alice"},
                {"id": "voice_2", "name": "Bob"},
                {"id": "voice_3", "name": "Charlie"}
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(VoicesResponse.self, from: data)

        #expect(response.voices.count == 3)
        #expect(response.voices[0].name == "Alice")
        #expect(response.voices[1].name == "Bob")
        #expect(response.voices[2].name == "Charlie")
    }

    // MARK: - TTSJob Model Tests

    /// Test TTSJob model decoding with all fields (id, status, text, voice_id, created_at)
    @Test("TTSJob model decodes with all fields correctly")
    func testTTSJobDecoding() throws {
        let json = """
        {
            "id": "job_abc123",
            "status": "completed",
            "text": "Hello, world!",
            "voice_id": "voice_1",
            "created_at": "2024-12-18T10:30:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let job = try decoder.decode(TTSJob.self, from: data)

        #expect(job.id == "job_abc123")
        #expect(job.status == .completed)
        #expect(job.text == "Hello, world!")
        #expect(job.voiceId == "voice_1")
        #expect(job.createdAt != nil)
    }

    /// Test job status enum parsing (pending, processing, completed, failed)
    @Test("JobStatus enum parses all status values correctly")
    func testJobStatusParsing() throws {
        let statuses = ["pending", "processing", "completed", "failed"]
        let expected: [JobStatus] = [.pending, .processing, .completed, .failed]

        for (index, statusString) in statuses.enumerated() {
            let json = """
            {
                "id": "job_\(index)",
                "status": "\(statusString)",
                "text": "Test",
                "voice_id": "voice_1",
                "created_at": "2024-12-18T10:30:00Z"
            }
            """

            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let job = try decoder.decode(TTSJob.self, from: data)

            #expect(job.status == expected[index])
        }
    }

    /// Test TTSJob text preview truncation
    @Test("TTSJob textPreview truncates long text correctly")
    func testTextPreviewTruncation() throws {
        let shortJson = """
        {
            "id": "job_1",
            "status": "completed",
            "text": "Short text",
            "voice_id": "voice_1",
            "created_at": "2024-12-18T10:30:00Z"
        }
        """

        let longJson = """
        {
            "id": "job_2",
            "status": "completed",
            "text": "This is a very long text that should definitely be truncated because it exceeds fifty characters",
            "voice_id": "voice_1",
            "created_at": "2024-12-18T10:30:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let shortJob = try decoder.decode(TTSJob.self, from: shortJson.data(using: .utf8)!)
        let longJob = try decoder.decode(TTSJob.self, from: longJson.data(using: .utf8)!)

        #expect(shortJob.textPreview == "Short text")
        #expect(longJob.textPreview.count == 53) // 50 chars + "..."
        #expect(longJob.textPreview.hasSuffix("..."))
    }

    /// Test CreateJobRequest encoding
    @Test("CreateJobRequest encodes to JSON correctly with snake_case")
    func testCreateJobRequestEncoding() throws {
        let request = CreateJobRequest(text: "Hello world", voiceId: "voice_123")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString.contains("\"text\":\"Hello world\""))
        #expect(jsonString.contains("\"voice_id\":\"voice_123\""))
    }
}
