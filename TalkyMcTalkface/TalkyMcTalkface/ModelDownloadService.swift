import Foundation
import Combine

/// Response model for model download progress from Python backend
struct ModelDownloadProgress: Codable, Equatable {
    let status: String
    let progress: Double
    let downloadedBytes: Int64
    let totalBytes: Int64
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case progress
        case downloadedBytes = "downloaded_bytes"
        case totalBytes = "total_bytes"
        case message
    }

    /// Whether the download is complete
    var isComplete: Bool {
        status == "completed"
    }

    /// Whether an error occurred
    var isError: Bool {
        status == "error"
    }

    /// Whether download is in progress
    var isDownloading: Bool {
        status == "downloading"
    }
}

/// Response model for triggering model download
struct ModelDownloadResponse: Codable {
    let status: String
    let message: String
}

/// Errors that can occur during model download
enum ModelDownloadError: Error, LocalizedError {
    case downloadFailed(String)
    case networkError(Error)
    case invalidResponse
    case alreadyDownloading
    case backendNotRunning

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .alreadyDownloading:
            return "Download already in progress"
        case .backendNotRunning:
            return "Backend server is not running"
        }
    }
}

/// Service for managing model download from the Python backend
/// Task 3.4: Implement model download service
@MainActor
class ModelDownloadService: ObservableObject {
    /// Server configuration - matching SubprocessManager
    static let serverHost = "127.0.0.1"
    static let serverPort = 5111
    static let downloadURL = URL(string: "http://\(serverHost):\(serverPort)/model/download")!
    static let progressURL = URL(string: "http://\(serverHost):\(serverPort)/model/progress")!

    /// Progress polling interval in seconds
    private let progressPollInterval: TimeInterval = 0.5

    /// Published state
    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var errorMessage: String?

    /// Internal state
    private var progressTimer: Timer?
    private var downloadTask: Task<Void, Never>?

    /// Callback for when download completes successfully
    var onDownloadComplete: (() -> Void)?

    /// Callback for download errors
    var onDownloadError: ((Error) -> Void)?

    init() {}

    /// Cleanup resources - must be called before releasing the service
    func cleanup() {
        progressTimer?.invalidate()
        progressTimer = nil
        downloadTask?.cancel()
        downloadTask = nil
    }

    // MARK: - Public Interface

    /// Start the model download
    /// Task 3.4: Download model files from Python backend
    func startDownload() async throws {
        guard !isDownloading else {
            throw ModelDownloadError.alreadyDownloading
        }

        isDownloading = true
        progress = 0.0
        downloadedBytes = 0
        totalBytes = 0
        errorMessage = nil
        statusMessage = "Starting download..."

        do {
            // Trigger download on the Python backend
            try await triggerDownload()

            // Start polling for progress
            startProgressPolling()

        } catch {
            isDownloading = false
            errorMessage = error.localizedDescription
            onDownloadError?(error)
            throw error
        }
    }

    /// Cancel the current download
    func cancelDownload() {
        progressTimer?.invalidate()
        progressTimer = nil
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusMessage = "Download cancelled"
    }

    // MARK: - Private Implementation

    /// Trigger the download on the Python backend
    private func triggerDownload() async throws {
        var request = URLRequest(url: Self.downloadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelDownloadError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let downloadResponse = try decoder.decode(ModelDownloadResponse.self, from: data)
                statusMessage = downloadResponse.message
            } else if httpResponse.statusCode == 409 {
                // Already downloading - that's fine, we'll poll for progress
                statusMessage = "Download in progress..."
            } else {
                throw ModelDownloadError.downloadFailed("Server returned status \(httpResponse.statusCode)")
            }
        } catch let error as ModelDownloadError {
            throw error
        } catch {
            throw ModelDownloadError.networkError(error)
        }
    }

    /// Start polling for download progress
    private func startProgressPolling() {
        progressTimer?.invalidate()

        progressTimer = Timer.scheduledTimer(withTimeInterval: progressPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollProgress()
            }
        }
    }

    /// Poll the backend for current download progress
    private func pollProgress() async {
        guard isDownloading else {
            progressTimer?.invalidate()
            progressTimer = nil
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: Self.progressURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let decoder = JSONDecoder()
            let progressResponse = try decoder.decode(ModelDownloadProgress.self, from: data)

            // Update published state
            progress = progressResponse.progress
            downloadedBytes = progressResponse.downloadedBytes
            totalBytes = progressResponse.totalBytes
            statusMessage = progressResponse.message

            if progressResponse.isComplete {
                // Download finished successfully
                progressTimer?.invalidate()
                progressTimer = nil
                isDownloading = false
                onDownloadComplete?()
            } else if progressResponse.isError {
                // Download failed
                progressTimer?.invalidate()
                progressTimer = nil
                isDownloading = false
                errorMessage = progressResponse.message
                onDownloadError?(ModelDownloadError.downloadFailed(progressResponse.message))
            }

        } catch {
            // Network error during polling - may be transient, keep trying
            print("[ModelDownloadService] Progress poll error: \(error.localizedDescription)")
        }
    }

    // MARK: - Formatting Helpers

    /// Format bytes for display (e.g., "450 MB / 1.2 GB")
    var formattedProgress: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let downloadedStr = formatter.string(fromByteCount: downloadedBytes)
        let totalStr = formatter.string(fromByteCount: totalBytes)

        if totalBytes > 0 {
            return "\(downloadedStr) / \(totalStr)"
        } else {
            return downloadedStr
        }
    }

    /// Format progress as percentage (e.g., "45%")
    var formattedPercentage: String {
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }
}
