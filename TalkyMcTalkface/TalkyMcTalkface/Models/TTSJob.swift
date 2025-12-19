import Foundation

/// Status of a TTS job
/// Task 1.3: Create TTSJob model with JobStatus enum
enum JobStatus: String, Codable, Equatable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"

    /// SF Symbol icon name for status display
    var iconName: String {
        switch self {
        case .pending:
            return "clock"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    /// Color for status icon
    var iconColorName: String {
        switch self {
        case .pending:
            return "secondary"
        case .processing:
            return "blue"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }
}

/// Model representing a TTS job
/// Task 1.3: Create TTSJob model
struct TTSJob: Codable, Identifiable, Equatable {
    /// Unique identifier for the job
    let id: String

    /// Current status of the job
    let status: JobStatus

    /// Text that was submitted for synthesis
    let text: String

    /// ID of the voice used for synthesis (nil for default voice)
    let voiceId: String?

    /// Timestamp when the job was created
    let createdAt: Date

    /// CodingKeys for snake_case conversion from API
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case text
        case voiceId = "voice_id"
        case createdAt = "created_at"
    }

    /// Truncated text preview (first 50 characters)
    var textPreview: String {
        if text.count <= 50 {
            return text
        }
        return String(text.prefix(50)) + "..."
    }

    /// Relative timestamp string (e.g., "2m ago", "1h ago")
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// Response wrapper for GET /jobs endpoint
/// Task 1.4: Create API response wrapper models
struct JobsListResponse: Codable {
    let jobs: [TTSJob]
}

/// Request body for POST /jobs endpoint
/// Task 1.4: Create API response wrapper models
struct CreateJobRequest: Codable {
    let text: String
    let voiceId: String?

    enum CodingKeys: String, CodingKey {
        case text
        case voiceId = "voice_id"
    }

    /// Create request with optional voice (nil for default voice)
    init(text: String, voiceId: String?) {
        self.text = text
        // Convert "default" to nil to use the model's built-in voice
        self.voiceId = (voiceId == "default") ? nil : voiceId
    }
}

/// Response for POST /jobs endpoint
struct CreateJobResponse: Codable {
    let id: String
    let status: JobStatus
    let message: String?
}
