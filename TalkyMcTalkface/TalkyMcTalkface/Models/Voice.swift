import Foundation

/// Model representing an available TTS voice
/// Task 1.2: Create Voice model
struct Voice: Codable, Identifiable, Equatable, Hashable {
    /// Unique identifier for the voice
    let id: String

    /// Display name of the voice
    let name: String

    /// CodingKeys for snake_case conversion from API
    enum CodingKeys: String, CodingKey {
        case id
        case name = "display_name"
    }

    /// Default voice (uses model's built-in voice)
    static let defaultVoice = Voice(id: "default", name: "Chatterbox (Default)")
}

/// Response wrapper for GET /voices endpoint
/// Task 1.4: Create API response wrapper models
struct VoicesResponse: Codable {
    let voices: [Voice]
}
