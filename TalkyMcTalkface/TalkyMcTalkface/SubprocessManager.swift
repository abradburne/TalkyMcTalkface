import Foundation
import Combine

/// Response model for the Python backend health endpoint
struct HealthResponse: Codable {
    let status: String
    let modelLoaded: Bool
    let modelLoading: Bool
    let modelCached: Bool
    let availableVoices: [String]
    let version: String

    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case modelLoading = "model_loading"
        case modelCached = "model_cached"
        case availableVoices = "available_voices"
        case version
    }
}

/// Manages the Python backend subprocess lifecycle
@MainActor
class SubprocessManager: ObservableObject {
    /// Server configuration
    static let serverHost = "127.0.0.1"
    static let serverPort = 5111
    static let healthURL = URL(string: "http://\(serverHost):\(serverPort)/health")!

    /// Health check interval in seconds
    private let healthCheckInterval: TimeInterval = 5.0

    /// Graceful shutdown timeout in seconds
    private let shutdownTimeout: TimeInterval = 5.0

    /// Maximum restart attempts before giving up
    private let maxRestartAttempts = 3

    /// Published state
    @Published private(set) var isRunning = false
    @Published private(set) var lastHealthResponse: HealthResponse?
    @Published private(set) var lastError: String?

    /// Internal state
    private var process: Process?
    private var healthCheckTimer: Timer?
    private var restartAttempts = 0
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    /// Callback for status updates
    var onStatusChange: ((AppStatus) -> Void)?

    /// Callback for loading message updates
    var onLoadingMessageChange: ((String) -> Void)?

    init() {}

    /// Cleanup resources - call this before releasing the manager
    func cleanup() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    // MARK: - Public Interface

    /// Start the Python subprocess
    func start() async {
        guard !isRunning else { return }

        restartAttempts = 0
        await launchSubprocess()
    }

    /// Stop the Python subprocess gracefully
    func stop() async {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        guard let process = process, process.isRunning else {
            isRunning = false
            return
        }

        let pid = process.processIdentifier

        // Send SIGTERM for graceful shutdown
        process.terminate()

        // Wait for graceful termination with timeout
        let didTerminate = await waitForTermination(timeout: shutdownTimeout)

        if !didTerminate {
            // Force kill with SIGKILL if not responding
            // Kill the process group to catch child processes too
            kill(-pid, SIGKILL)  // Negative pid kills the process group
            kill(pid, SIGKILL)   // Also kill the main process directly
            // Give it a moment to actually die
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        self.process = nil
        isRunning = false
    }

    /// Perform a single health check
    func checkHealth() async -> HealthResponse? {
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.healthURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let decoder = JSONDecoder()
            let healthResponse = try decoder.decode(HealthResponse.self, from: data)
            lastHealthResponse = healthResponse
            lastError = nil
            return healthResponse
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Private Implementation

    /// Launch the Python subprocess
    private func launchSubprocess() async {
        onStatusChange?(.loading)
        onLoadingMessageChange?("Starting server...")

        guard let executablePath = findPythonExecutable() else {
            lastError = "Python executable not found in Resources"
            onStatusChange?(.error)
            return
        }

        let process = Process()
        process.executableURL = executablePath

        // Set working directory to the python-backend folder
        process.currentDirectoryURL = executablePath.deletingLastPathComponent()

        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        // Disable OpenMP parallelism to avoid shared memory issues
        environment["OMP_NUM_THREADS"] = "1"
        environment["MKL_NUM_THREADS"] = "1"
        environment["KMP_INIT_AT_FORK"] = "FALSE"
        environment["KMP_AFFINITY"] = "disabled"
        environment["KMP_WARNINGS"] = "0"
        environment["OPENBLAS_NUM_THREADS"] = "1"
        environment["VECLIB_MAXIMUM_THREADS"] = "1"
        environment["NUMEXPR_NUM_THREADS"] = "1"

        // Pass HuggingFace token from Keychain if available
        if let hfToken = KeychainService.shared.getHuggingFaceToken(), !hfToken.isEmpty {
            environment["HF_TOKEN"] = hfToken
            print("[SubprocessManager] HuggingFace token configured")
        }

        process.environment = environment

        print("[SubprocessManager] Launching: \(executablePath.path)")
        print("[SubprocessManager] Working dir: \(executablePath.deletingLastPathComponent().path)")

        // Capture stdout/stderr for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        // Handle output asynchronously
        setupOutputHandlers(outputPipe: outputPipe, errorPipe: errorPipe)

        // Set up termination handler
        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor in
                self?.handleProcessTermination(terminatedProcess)
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true

            // Wait for server to be ready
            await waitForServerReady()

            // Start health monitoring
            startHealthMonitoring()

        } catch {
            lastError = "Failed to launch subprocess: \(error.localizedDescription)"
            onStatusChange?(.error)
            isRunning = false
        }
    }

    /// Find the Python executable in the app bundle Resources
    private func findPythonExecutable() -> URL? {
        // Look for bundled Python backend in Resources
        if let resourcePath = Bundle.main.resourcePath {
            let bundledPath = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("python-backend")
                .appendingPathComponent("TalkyMcTalkface")

            if FileManager.default.isExecutableFile(atPath: bundledPath.path) {
                return bundledPath
            }
        }

        // For development: look for a dev server script
        // This allows testing before PyInstaller bundling is complete
        if let devServerPath = findDevelopmentServer() {
            return devServerPath
        }

        return nil
    }

    /// Find development server for testing (before PyInstaller bundling)
    private func findDevelopmentServer() -> URL? {
        // Check for development Python script
        // During development, we can run the server directly with Python
        let possiblePaths = [
            // Relative to the Xcode project
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("server.py"),
            // Common development location
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("src/tries/2025-12-17-talk/server.py")
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                // For Python scripts, we need to return the Python interpreter
                // and set the script as an argument
                // For now, return nil as we expect the bundled executable
                return nil
            }
        }

        return nil
    }

    /// Set up handlers for subprocess output
    private func setupOutputHandlers(outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                // Log stdout for debugging
                print("[Python stdout] \(output)", terminator: "")
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                // Log stderr for debugging
                print("[Python stderr] \(output)", terminator: "")
            }
        }
    }

    /// Wait for the server to become ready
    private func waitForServerReady() async {
        let maxAttempts = 30 // 15 seconds total (500ms * 30) - just wait for server to respond

        for attempt in 1...maxAttempts {
            if let health = await checkHealth() {
                // Server is responding - determine status based on model state
                if health.modelLoaded {
                    onLoadingMessageChange?("Ready!")
                    onStatusChange?(.ready)
                } else if health.modelLoading {
                    // Model is loading in background - show loading status
                    onLoadingMessageChange?("Loading TTS model... (this takes ~30 seconds)")
                    onStatusChange?(.loading)
                } else if health.modelCached {
                    // Cached but not loading yet - will start soon
                    onLoadingMessageChange?("Preparing to load model...")
                    onStatusChange?(.loading)
                } else {
                    // Not cached, not loading - needs download
                    onStatusChange?(.downloadRequired)
                }
                return
            }

            // Update message while waiting for server
            if attempt <= 5 {
                onLoadingMessageChange?("Starting server...")
            } else {
                onLoadingMessageChange?("Waiting for server to respond...")
            }

            // Wait 500ms before retry
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Check if process died while waiting
            if process == nil || !(process?.isRunning ?? false) {
                return
            }
        }

        // Server did not become ready in time
        lastError = "Server did not respond within timeout"
        onStatusChange?(.error)
    }

    /// Start periodic health monitoring
    private func startHealthMonitoring() {
        healthCheckTimer?.invalidate()

        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performHealthCheck()
            }
        }
    }

    /// Perform a health check and update status
    private func performHealthCheck() async {
        guard isRunning else { return }

        if let health = await checkHealth() {
            if health.modelLoaded {
                onStatusChange?(.ready)
            } else if health.modelLoading {
                onLoadingMessageChange?("Loading TTS model... (this takes ~30 seconds)")
                onStatusChange?(.loading)
            } else if health.modelCached {
                // Cached but not loading - may be starting to load
                onLoadingMessageChange?("Preparing to load model...")
                onStatusChange?(.loading)
            } else {
                onStatusChange?(.downloadRequired)
            }
            restartAttempts = 0
        } else {
            // Health check failed - server may have crashed
            if process?.isRunning == false {
                await handleUnexpectedTermination()
            }
        }
    }

    /// Handle process termination
    private func handleProcessTermination(_ process: Process) {
        let exitCode = process.terminationStatus
        let reason = process.terminationReason

        print("[SubprocessManager] Process terminated with code \(exitCode), reason: \(reason)")

        isRunning = false

        // Clear pipes
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
        self.process = nil

        // If this was not a graceful shutdown, handle restart
        if exitCode != 0 {
            Task {
                await handleUnexpectedTermination()
            }
        }
    }

    /// Handle unexpected subprocess termination
    private func handleUnexpectedTermination() async {
        guard restartAttempts < maxRestartAttempts else {
            lastError = "Server crashed repeatedly (\(maxRestartAttempts) times)"
            onStatusChange?(.error)
            return
        }

        restartAttempts += 1
        print("[SubprocessManager] Attempting restart \(restartAttempts)/\(maxRestartAttempts)")

        // Wait a moment before restart
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        await launchSubprocess()
    }

    /// Wait for process termination with timeout
    private func waitForTermination(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if process?.isRunning == false {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return process?.isRunning == false
    }
}
