import Foundation

/// Errors that can occur during job operations
enum JobServiceError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case jobCreationFailed(String)
    case jobNotFound
    case audioNotAvailable

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .jobCreationFailed(let message):
            return "Failed to create job: \(message)"
        case .jobNotFound:
            return "Job not found"
        case .audioNotAvailable:
            return "Audio not available for this job"
        }
    }
}

/// Service for managing TTS jobs with the backend
/// Task 2.3: Create JobService
@MainActor
class JobService: ObservableObject {
    /// Server configuration - matching SubprocessManager
    static let serverHost = "127.0.0.1"
    static let serverPort = 5111
    static let baseURL = "http://\(serverHost):\(serverPort)"
    static let jobsURL = URL(string: "\(baseURL)/jobs")!

    /// Polling interval for job status
    private let pollingInterval: TimeInterval = 1.0

    /// Published state
    @Published private(set) var jobs: [TTSJob] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Internal state
    private var pollingTimer: Timer?
    private var currentPollingJobId: String?

    /// Callbacks for job events
    var onJobComplete: ((TTSJob) -> Void)?
    var onJobError: ((Error) -> Void)?

    /// JSON decoder configured for API responses
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Custom date decoding for Python datetime format (no timezone)
        // Format: "2025-12-18T05:57:42.309397"
        let formatterWithFractional = DateFormatter()
        formatterWithFractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatterWithFractional.locale = Locale(identifier: "en_US_POSIX")
        formatterWithFractional.timeZone = TimeZone(secondsFromGMT: 0)

        let formatterWithoutFractional = DateFormatter()
        formatterWithoutFractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatterWithoutFractional.locale = Locale(identifier: "en_US_POSIX")
        formatterWithoutFractional.timeZone = TimeZone(secondsFromGMT: 0)

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatterWithFractional.date(from: dateString) {
                return date
            }
            if let date = formatterWithoutFractional.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }
        return decoder
    }()

    /// JSON encoder for API requests
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    init() {}

    /// Cleanup resources
    func cleanup() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentPollingJobId = nil
    }

    // MARK: - Public Interface

    /// Create a new TTS job
    /// Task 2.3: createJob(text: String, voiceId: String) async throws -> TTSJob
    func createJob(text: String, voiceId: String) async throws -> TTSJob {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let request = CreateJobRequest(text: text, voiceId: voiceId)

        var urlRequest = URLRequest(url: Self.jobsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                throw JobServiceError.jobCreationFailed("Server returned status \(httpResponse.statusCode)")
            }

            let job = try decoder.decode(TTSJob.self, from: data)
            return job

        } catch let error as JobServiceError {
            errorMessage = error.localizedDescription
            throw error
        } catch let error as DecodingError {
            let jobError = JobServiceError.decodingError(error)
            errorMessage = jobError.localizedDescription
            throw jobError
        } catch {
            let jobError = JobServiceError.networkError(error)
            errorMessage = jobError.localizedDescription
            throw jobError
        }
    }

    /// Fetch all jobs
    /// Task 2.3: fetchJobs() async throws -> [TTSJob]
    func fetchJobs() async throws -> [TTSJob] {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.jobsURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw JobServiceError.invalidResponse
            }

            let jobsResponse = try decoder.decode(JobsListResponse.self, from: data)
            // Sort by creation date descending (most recent first)
            let sortedJobs = jobsResponse.jobs.sorted { $0.createdAt > $1.createdAt }
            jobs = sortedJobs
            return sortedJobs

        } catch let error as JobServiceError {
            throw error
        } catch let error as DecodingError {
            throw JobServiceError.decodingError(error)
        } catch {
            throw JobServiceError.networkError(error)
        }
    }

    /// Fetch a single job by ID
    /// Task 2.3: fetchJob(id: String) async throws -> TTSJob
    func fetchJob(id: String) async throws -> TTSJob {
        let url = URL(string: "\(Self.baseURL)/jobs/\(id)")!

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw JobServiceError.jobNotFound
            }

            guard httpResponse.statusCode == 200 else {
                throw JobServiceError.invalidResponse
            }

            let job = try decoder.decode(TTSJob.self, from: data)
            return job

        } catch let error as JobServiceError {
            throw error
        } catch let error as DecodingError {
            throw JobServiceError.decodingError(error)
        } catch {
            throw JobServiceError.networkError(error)
        }
    }

    /// Delete a job by ID
    /// Task 2.3: deleteJob(id: String) async throws
    func deleteJob(id: String) async throws {
        let url = URL(string: "\(Self.baseURL)/jobs/\(id)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw JobServiceError.jobNotFound
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw JobServiceError.invalidResponse
            }

            // Remove from local cache
            jobs.removeAll { $0.id == id }

        } catch let error as JobServiceError {
            throw error
        } catch {
            throw JobServiceError.networkError(error)
        }
    }

    /// Delete all jobs
    /// Task 2.3: deleteAllJobs() async throws
    func deleteAllJobs() async throws {
        var urlRequest = URLRequest(url: Self.jobsURL)
        urlRequest.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw JobServiceError.invalidResponse
            }

            // Clear local cache
            jobs = []

        } catch let error as JobServiceError {
            throw error
        } catch {
            throw JobServiceError.networkError(error)
        }
    }

    /// Fetch audio data for a job
    /// Task 2.5: fetchAudioData(jobId: String) async throws -> Data
    func fetchAudioData(jobId: String) async throws -> Data {
        let url = URL(string: "\(Self.baseURL)/jobs/\(jobId)/audio")!

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw JobServiceError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                throw JobServiceError.audioNotAvailable
            }

            guard httpResponse.statusCode == 200 else {
                throw JobServiceError.invalidResponse
            }

            return data

        } catch let error as JobServiceError {
            throw error
        } catch {
            throw JobServiceError.networkError(error)
        }
    }

    // MARK: - Job Status Polling

    /// Start polling for job status
    /// Task 2.4: Timer-based polling following ModelDownloadService pattern
    func startPolling(jobId: String) {
        stopPolling()

        currentPollingJobId = jobId
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollJobStatus()
            }
        }
    }

    /// Stop polling for job status
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentPollingJobId = nil
    }

    /// Poll the current job's status
    private func pollJobStatus() async {
        guard let jobId = currentPollingJobId else {
            stopPolling()
            return
        }

        do {
            let job = try await fetchJob(id: jobId)

            if job.status == .completed {
                stopPolling()
                onJobComplete?(job)
            } else if job.status == .failed {
                stopPolling()
                onJobError?(JobServiceError.jobCreationFailed("Job processing failed"))
            }
            // If still pending or processing, continue polling

        } catch {
            // Network error during polling - may be transient, keep trying
            print("[JobService] Poll error: \(error.localizedDescription)")
        }
    }
}
