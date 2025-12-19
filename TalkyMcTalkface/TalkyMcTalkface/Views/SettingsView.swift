import SwiftUI
import ServiceManagement

/// Configuration for Voice Library feature
enum VoiceLibraryConfig {
    /// Path to the voices folder in Application Support
    static let voicesFolderPath: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TalkyMcTalkface/voices").path
    }()

    /// URL to the voices folder for NSWorkspace
    static var voicesFolderURL: URL? {
        URL(fileURLWithPath: voicesFolderPath)
    }

    /// URL to browse voices online (placeholder for future website)
    static let browseVoicesURL: URL? = URL(string: "https://example.com/voices")
}

/// Settings view for app configuration
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @StateObject private var cliService = CLIInstallService()
    @State private var launchAtLoginEnabled: Bool

    init(appState: AppState) {
        self.appState = appState
        // Initialize with current setting
        _launchAtLoginEnabled = State(initialValue: appState.settings.launchAtLogin)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Default Voice Section
                defaultVoiceSection

                Divider()

                // Launch at Login Section
                launchAtLoginSection

                Divider()

                // Model Management Section
                modelManagementSection

                Divider()

                // Voice Library Section
                voiceLibrarySection

                Divider()

                // Server & API Section
                serverApiSection

                Divider()

                // CLI Installation Section
                cliInstallSection
            }
        }
        .frame(maxHeight: 500)
    }

    // MARK: - Voice Library Section

    private var voiceLibrarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Library")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Add custom voice prompts by dropping .wav files into the voices folder")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open Voices Folder") {
                    openVoicesFolder()
                }
                .buttonStyle(.bordered)

                Button("Browse Voices Online") {
                    browseVoicesOnline()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func openVoicesFolder() {
        // Create voices directory if it doesn't exist
        let fileManager = FileManager.default
        let voicesPath = VoiceLibraryConfig.voicesFolderPath

        if !fileManager.fileExists(atPath: voicesPath) {
            do {
                try fileManager.createDirectory(atPath: voicesPath, withIntermediateDirectories: true)
            } catch {
                print("Failed to create voices folder: \(error.localizedDescription)")
            }
        }

        // Open the folder in Finder
        if let url = VoiceLibraryConfig.voicesFolderURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func browseVoicesOnline() {
        if let url = VoiceLibraryConfig.browseVoicesURL {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Server & API Section

    private var serverApiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server & API")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Access the local server for automation and scripting")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Open Web UI") {
                    if let url = URL(string: "http://127.0.0.1:5111") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                Button("API Documentation") {
                    if let url = URL(string: "http://127.0.0.1:5111/docs") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("Server runs at http://127.0.0.1:5111")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - CLI Installation Section

    private var cliInstallSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command Line Tool")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Install 'talky' command for terminal usage")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cliStatusText)
                        .font(.body)
                    if cliService.status == .installed {
                        Text(cliService.installPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if cliService.status == .installed {
                    Button("Uninstall") {
                        cliService.uninstall()
                    }
                    .buttonStyle(.bordered)

                    Button("Usage") {
                        cliService.showUsage()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Install") {
                        cliService.install()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = cliService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var cliStatusText: String {
        switch cliService.status {
        case .checking:
            return "Checking..."
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Not installed"
        case .needsUpdate:
            return "Update available"
        }
    }

    // MARK: - Default Voice Section

    private var defaultVoiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Voice")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Voice used for clipboard TTS and new jobs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Default Voice", selection: Binding(
                get: { appState.selectedVoiceId },
                set: { newValue in
                    if let id = newValue {
                        appState.updateDefaultVoice(id: id)
                    }
                }
            )) {
                if appState.voices.isEmpty {
                    Text("Loading voices...").tag(nil as String?)
                } else {
                    ForEach(appState.voices) { voice in
                        Text(voice.name).tag(voice.id as String?)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(appState.voices.isEmpty)
        }
    }

    // MARK: - Launch at Login Section

    /// Task 7.7: Implement launch at login
    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $launchAtLoginEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Start TalkyMcTalkface when you log in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                updateLaunchAtLogin(enabled: newValue)
            }
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        appState.updateLaunchAtLogin(enabled: enabled)

        // Use SMAppService for modern macOS (13+)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error.localizedDescription)")
                // Revert the toggle on failure
                launchAtLoginEnabled = !enabled
            }
        }
    }

    // MARK: - Model Management Section

    private var modelManagementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Management")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TTS Model")
                        .font(.body)
                    Text(modelStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Re-download") {
                    Task {
                        await appState.startModelDownload()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.status == .downloading)
            }
        }
    }

    private var modelStatusText: String {
        switch appState.status {
        case .ready:
            return "Loaded and ready"
        case .downloading:
            return "Downloading..."
        case .downloadRequired:
            return "Not downloaded"
        default:
            return "Unknown"
        }
    }
}

#Preview {
    SettingsView(appState: {
        let state = AppState()
        state.setStatus(.ready)
        return state
    }())
    .padding()
    .frame(width: 380)
}
