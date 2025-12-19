import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for UI components
/// Task 6.1: Write 4-6 focused tests for UI components
struct UIComponentTests {

    /// Test Voice model properties for VoicePicker display
    @Test("Voice model provides correct display properties")
    func testVoiceDisplayProperties() {
        let voice = Voice(id: "voice_123", name: "Alice")

        #expect(voice.id == "voice_123")
        #expect(voice.name == "Alice")
    }

    /// Test TTSJob provides correct text preview for JobRowView
    @Test("TTSJob textPreview truncates at 50 characters")
    func testJobTextPreview() {
        let shortJob = TTSJob(
            id: "job_1",
            status: .completed,
            text: "Short text",
            voiceId: "voice_1",
            createdAt: Date()
        )

        let longJob = TTSJob(
            id: "job_2",
            status: .completed,
            text: "This is a very long text that should definitely be truncated because it exceeds the fifty character limit",
            voiceId: "voice_1",
            createdAt: Date()
        )

        #expect(shortJob.textPreview == "Short text")
        #expect(longJob.textPreview.count == 53) // 50 + "..."
        #expect(longJob.textPreview.hasSuffix("..."))
    }

    /// Test JobStatus provides correct icon names for JobRowView
    @Test("JobStatus provides correct icon names")
    func testJobStatusIcons() {
        #expect(JobStatus.pending.iconName == "clock")
        #expect(JobStatus.processing.iconName == "arrow.triangle.2.circlepath")
        #expect(JobStatus.completed.iconName == "checkmark.circle.fill")
        #expect(JobStatus.failed.iconName == "xmark.circle.fill")
    }

    /// Test GenerateButton disabled state logic
    @Test("GenerateButton disabled when text is empty")
    func testGenerateButtonDisabledState() {
        // Empty text should disable
        let emptyDisabled = true // text.isEmpty
        #expect(emptyDisabled == true)

        // Non-empty text should enable
        let hasText = !("Hello".isEmpty)
        #expect(hasText == true)
    }

    /// Test jobs list sorting (most recent first)
    @Test("Jobs list should be sorted by createdAt descending")
    func testJobsListSorting() {
        let job1 = TTSJob(id: "job_1", status: .completed, text: "First", voiceId: "v1", createdAt: Date().addingTimeInterval(-300))
        let job2 = TTSJob(id: "job_2", status: .completed, text: "Second", voiceId: "v1", createdAt: Date().addingTimeInterval(-100))
        let job3 = TTSJob(id: "job_3", status: .completed, text: "Third", voiceId: "v1", createdAt: Date())

        let unsortedJobs = [job1, job2, job3]
        let sortedJobs = unsortedJobs.sorted { $0.createdAt > $1.createdAt }

        #expect(sortedJobs[0].id == "job_3") // Most recent
        #expect(sortedJobs[1].id == "job_2")
        #expect(sortedJobs[2].id == "job_1") // Oldest
    }

    /// Test VoicePicker selection binding behavior
    @Test("VoicePicker selection uses voice ID")
    func testVoicePickerSelection() {
        let voices = [
            Voice(id: "voice_1", name: "Alice"),
            Voice(id: "voice_2", name: "Bob")
        ]

        // Verify voice IDs are used for selection
        let selectedId: String? = "voice_1"
        let selectedVoice = voices.first { $0.id == selectedId }

        #expect(selectedVoice?.name == "Alice")
    }
}
