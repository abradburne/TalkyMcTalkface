import Foundation

/// Errors that can occur during voice operations
enum VoiceServiceError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode voices: \(error.localizedDescription)"
        }
    }
}

/// Service for fetching available TTS voices from the backend
/// Task 2.2: Create VoiceService
@MainActor
class VoiceService: ObservableObject {
    /// Server configuration - matching SubprocessManager
    static let serverHost = "127.0.0.1"
    static let serverPort = 5111
    static let voicesURL = URL(string: "http://\(serverHost):\(serverPort)/voices")!

    /// Published state
    @Published private(set) var voices: [Voice] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// JSON decoder configured for API responses
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init() {}

    /// Fetch available voices from the backend
    /// Task 2.2: Method fetchVoices() async throws -> [Voice]
    func fetchVoices() async throws -> [Voice] {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: Self.voicesURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoiceServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw VoiceServiceError.invalidResponse
            }

            let voicesResponse = try decoder.decode(VoicesResponse.self, from: data)
            // Prepend default voice to the list
            voices = [Voice.defaultVoice] + voicesResponse.voices
            return voices

        } catch let error as VoiceServiceError {
            errorMessage = error.localizedDescription
            throw error
        } catch let error as DecodingError {
            let voiceError = VoiceServiceError.decodingError(error)
            errorMessage = voiceError.localizedDescription
            throw voiceError
        } catch {
            let voiceError = VoiceServiceError.networkError(error)
            errorMessage = voiceError.localizedDescription
            throw voiceError
        }
    }
}
