import Foundation
import Combine
import AppKit

/// Represents the current status of the application
enum AppStatus: String, Equatable {
    case ready = "Ready"
    case loading = "Loading"
    case error = "Error"
    case downloadRequired = "Download Required"
    case downloading = "Downloading"

    var iconName: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .loading:
            return "arrow.clockwise.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .downloadRequired:
            return "arrow.down.circle.fill"
        case .downloading:
            return "arrow.down.circle.fill"
        }
    }

    var statusDescription: String {
        switch self {
        case .ready:
            return "TalkyMcTalkface is ready to use."
        case .loading:
            return "Starting up..."
        case .error:
            return "An error occurred. Please try restarting."
        case .downloadRequired:
            return "The TTS model needs to be downloaded before use."
        case .downloading:
            return "Downloading model..."
        }
    }
}

/// Observable object that manages the application state
/// Task 5.4: Integrate settings with app lifecycle
/// Task 2.3: Integrate subprocess manager with app state
/// Task 3.2, 3.4: Integrate model download service
/// Task 4.0: Extend AppState with voice, job, and audio functionality
@MainActor
class AppState: ObservableObject {
    @Published var status: AppStatus = .loading
    @Published var errorMessage: String?

    // MARK: - Voice State (Task 4.2)

    /// Available voices from the backend
    @Published var voices: [Voice] = []

    /// Currently selected voice ID
    @Published var selectedVoiceId: String?

    /// Whether voices are being loaded
    @Published var isLoadingVoices = false

    // MARK: - Job State (Task 4.3)

    /// List of TTS jobs
    @Published var jobs: [TTSJob] = []

    /// Whether a TTS generation is in progress
    @Published var isGenerating = false

    /// Current text input for TTS generation
    @Published var currentInputText = ""

    // MARK: - Services

    /// Settings service instance - loaded during app initialization
    let settingsService: SettingsService

    /// Subprocess manager for the Python backend
    let subprocessManager: SubprocessManager

    /// Model download service for first-launch experience
    let modelDownloadService: ModelDownloadService

    /// Voice service for fetching available voices (Task 4.2)
    let voiceService: VoiceService

    /// Job service for TTS job management (Task 4.3)
    let jobService: JobService

    /// Audio player service for playback (Task 4.4)
    let audioPlayerService: AudioPlayerService

    // MARK: - Audio State Passthrough (Task 4.4)

    /// Whether audio is currently playing
    var isPlaying: Bool {
        audioPlayerService.isPlaying
    }

    /// ID of the job currently playing
    var currentPlayingJobId: String? {
        audioPlayerService.currentJobId
    }

    init() {
        // Task 5.4: Load settings during app initialization
        self.settingsService = SettingsService()

        // Task 2.2: Initialize subprocess manager
        self.subprocessManager = SubprocessManager()

        // Task 3.4: Initialize model download service
        self.modelDownloadService = ModelDownloadService()

        // Task 4.2: Initialize voice service
        self.voiceService = VoiceService()

        // Task 4.3: Initialize job service
        self.jobService = JobService()

        // Task 4.4: Initialize audio player service
        self.audioPlayerService = AudioPlayerService()

        // Set up subprocess status callbacks
        setupSubprocessCallbacks()

        // Set up model download callbacks
        setupModelDownloadCallbacks()

        // Set up job service callbacks
        setupJobServiceCallbacks()

        // Set up audio player callbacks
        setupAudioPlayerCallbacks()
    }

    /// Set up callbacks to receive status updates from subprocess manager
    private func setupSubprocessCallbacks() {
        subprocessManager.onStatusChange = { [weak self] newStatus in
            Task { @MainActor in
                // Don't override downloading status from subprocess updates
                if self?.status == .downloading {
                    return
                }
                self?.status = newStatus
                if newStatus == .error {
                    self?.errorMessage = self?.subprocessManager.lastError
                } else {
                    self?.errorMessage = nil
                }

                // Fetch voices when status becomes ready (Task 4.5)
                if newStatus == .ready {
                    await self?.fetchVoices()
                }
            }
        }
    }

    /// Set up callbacks for model download events
    private func setupModelDownloadCallbacks() {
        modelDownloadService.onDownloadComplete = { [weak self] in
            Task { @MainActor in
                // Refresh health status after download completes
                await self?.checkBackendHealth()
            }
        }

        modelDownloadService.onDownloadError = { [weak self] error in
            Task { @MainActor in
                self?.status = .error
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Set up callbacks for job service events
    private func setupJobServiceCallbacks() {
        jobService.onJobComplete = { [weak self] job in
            Task { @MainActor in
                self?.isGenerating = false
                // Auto-play audio on completion (Task 4.6)
                await self?.playJob(id: job.id)
                // Refresh jobs list
                await self?.refreshJobs()
            }
        }

        jobService.onJobError = { [weak self] error in
            Task { @MainActor in
                self?.isGenerating = false
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Set up callbacks for audio player events
    private func setupAudioPlayerCallbacks() {
        audioPlayerService.onPlaybackComplete = { [weak self] in
            Task { @MainActor in
                // Could add any post-playback behavior here
                self?.objectWillChange.send()
            }
        }
    }

    /// Update the application status
    func setStatus(_ newStatus: AppStatus) {
        status = newStatus
    }

    /// Access current application settings
    var settings: AppSettings {
        settingsService.settings
    }

    /// Update model unload timeout setting
    func updateModelUnloadTimeout(minutes: Int) {
        do {
            try settingsService.setModelUnloadTimeout(minutes: minutes)
        } catch {
            // Handle error gracefully - settings update failure should not crash the app
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Update launch at login setting
    func updateLaunchAtLogin(enabled: Bool) {
        do {
            try settingsService.setLaunchAtLogin(enabled: enabled)
        } catch {
            // Handle error gracefully - settings update failure should not crash the app
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Update default voice setting
    func updateDefaultVoice(id: String) {
        selectedVoiceId = id
        do {
            try settingsService.setDefaultVoice(id: id)
        } catch {
            print("Failed to save default voice: \(error.localizedDescription)")
        }
    }

    // MARK: - Backend Lifecycle Methods

    /// Start the Python backend subprocess
    func startBackend() async {
        status = .loading
        errorMessage = nil
        await subprocessManager.start()
    }

    /// Stop the Python backend subprocess
    func stopBackend() async {
        modelDownloadService.cleanup()
        jobService.cleanup()
        audioPlayerService.cleanup()
        await subprocessManager.stop()
    }

    /// Perform a health check on the Python backend
    func checkBackendHealth() async {
        if let health = await subprocessManager.checkHealth() {
            if health.modelLoaded {
                status = .ready
                // Fetch voices when ready
                await fetchVoices()
            } else {
                status = .downloadRequired
            }
            errorMessage = nil
        } else {
            // Health check failed
            if !subprocessManager.isRunning {
                status = .error
                errorMessage = subprocessManager.lastError ?? "Backend not running"
            }
        }
    }

    // MARK: - Model Download Methods

    /// Start downloading the TTS model
    func startModelDownload() async {
        status = .downloading
        errorMessage = nil

        do {
            try await modelDownloadService.startDownload()
        } catch {
            status = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Cancel the current model download
    func cancelModelDownload() {
        modelDownloadService.cancelDownload()
        status = .downloadRequired
    }

    // MARK: - Voice Methods (Task 4.5)

    /// Fetch available voices from the backend
    func fetchVoices() async {
        guard status == .ready else { return }

        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            let fetchedVoices = try await voiceService.fetchVoices()
            voices = fetchedVoices

            // Load selected voice from settings or default to first
            if let savedVoiceId = settingsService.settings.defaultVoiceId,
               fetchedVoices.contains(where: { $0.id == savedVoiceId }) {
                selectedVoiceId = savedVoiceId
            } else if let firstVoice = fetchedVoices.first {
                selectedVoiceId = firstVoice.id
            }
        } catch {
            print("Failed to fetch voices: \(error.localizedDescription)")
        }
    }

    // MARK: - Job Methods (Task 4.6, 4.7)

    /// Generate speech from current input text
    func generateSpeech() async {
        guard !currentInputText.isEmpty else { return }
        guard let voiceId = selectedVoiceId else { return }
        guard !isGenerating else { return }

        isGenerating = true
        errorMessage = nil

        do {
            let job = try await jobService.createJob(text: currentInputText, voiceId: voiceId)

            // Clear input text after successful submission
            currentInputText = ""

            // Start polling for job completion
            if job.status == .pending || job.status == .processing {
                jobService.startPolling(jobId: job.id)
            } else if job.status == .completed {
                // Job completed immediately (unlikely but handle it)
                isGenerating = false
                await playJob(id: job.id)
                await refreshJobs()
            }
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh the jobs list
    func refreshJobs() async {
        do {
            let fetchedJobs = try await jobService.fetchJobs()
            jobs = fetchedJobs
        } catch {
            print("Failed to refresh jobs: \(error.localizedDescription)")
        }
    }

    /// Play audio for a specific job
    func playJob(id: String) async {
        // Stop any current playback
        audioPlayerService.stop()

        do {
            let audioData = try await jobService.fetchAudioData(jobId: id)
            audioPlayerService.play(data: audioData, jobId: id)
        } catch {
            print("Failed to play job audio: \(error.localizedDescription)")
            errorMessage = "Failed to play audio"
        }
    }

    /// Delete a specific job
    func deleteJob(id: String) async {
        // Stop playback if this job is playing
        if currentPlayingJobId == id {
            audioPlayerService.stop()
        }

        do {
            try await jobService.deleteJob(id: id)
            jobs.removeAll { $0.id == id }
        } catch {
            print("Failed to delete job: \(error.localizedDescription)")
            errorMessage = "Failed to delete job"
        }
    }

    /// Delete all jobs
    func deleteAllJobs() async {
        // Stop any playback
        audioPlayerService.stop()

        do {
            try await jobService.deleteAllJobs()
            jobs = []
        } catch {
            print("Failed to delete all jobs: \(error.localizedDescription)")
            errorMessage = "Failed to delete jobs"
        }
    }

    /// Get audio data for downloading
    func getAudioData(jobId: String) async throws -> Data {
        return try await jobService.fetchAudioData(jobId: jobId)
    }

    // MARK: - Clipboard TTS (for global shortcut)

    /// Generate TTS from clipboard text
    func generateFromClipboard() async {
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.isEmpty else {
            return
        }

        // Use default voice
        guard let voiceId = selectedVoiceId ?? voices.first?.id else {
            return
        }

        isGenerating = true
        errorMessage = nil

        do {
            let job = try await jobService.createJob(text: clipboardText, voiceId: voiceId)

            // Start polling for job completion
            if job.status == .pending || job.status == .processing {
                jobService.startPolling(jobId: job.id)
            } else if job.status == .completed {
                isGenerating = false
                await playJob(id: job.id)
                await refreshJobs()
            }
        } catch {
            isGenerating = false
            errorMessage = error.localizedDescription
        }
    }
}
