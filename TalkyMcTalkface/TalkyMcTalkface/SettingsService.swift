import Foundation

/// Schema for application settings
struct AppSettings: Codable, Equatable {
    /// Model unload timeout in minutes (0 = never unload)
    var modelUnloadTimeoutMinutes: Int

    /// Whether to launch at login
    var launchAtLogin: Bool

    /// Default voice ID for TTS generation
    var defaultVoiceId: String?

    /// Default values for new installations
    static let defaultSettings = AppSettings(
        modelUnloadTimeoutMinutes: 0,
        launchAtLogin: false,
        defaultVoiceId: nil
    )

    /// Custom decoder to handle migration from old settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields with fallback to defaults
        modelUnloadTimeoutMinutes = try container.decodeIfPresent(Int.self, forKey: .modelUnloadTimeoutMinutes) ?? 0
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false

        // Optional fields
        defaultVoiceId = try container.decodeIfPresent(String.self, forKey: .defaultVoiceId)
    }

    /// Standard initializer
    init(
        modelUnloadTimeoutMinutes: Int = 0,
        launchAtLogin: Bool = false,
        defaultVoiceId: String? = nil
    ) {
        self.modelUnloadTimeoutMinutes = modelUnloadTimeoutMinutes
        self.launchAtLogin = launchAtLogin
        self.defaultVoiceId = defaultVoiceId
    }
}

/// Errors that can occur during settings operations
enum SettingsError: Error, LocalizedError {
    case directoryCreationFailed(Error)
    case saveFailed(Error)
    case loadFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let error):
            return "Failed to create settings directory: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save settings: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load settings: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode settings: \(error.localizedDescription)"
        }
    }
}

/// Service for managing application settings persistence
/// Task 5.3: Implement settings storage service
/// Stores settings in ~/Library/Application Support/TalkyMcTalkface/
@MainActor
class SettingsService: ObservableObject {
    /// Current application settings
    @Published private(set) var settings: AppSettings

    /// Path to the Application Support directory for this app
    static let applicationSupportDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("TalkyMcTalkface")
    }()

    /// Path to the settings file
    static let settingsFileURL: URL = {
        applicationSupportDirectory.appendingPathComponent("Settings.json")
    }()

    /// File manager instance
    private let fileManager = FileManager.default

    /// JSON encoder configured for settings
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    /// JSON decoder for settings
    private let decoder = JSONDecoder()

    /// Initialize the settings service
    /// Task 5.4: Load settings during app initialization
    init() {
        // Try to load existing settings, fall back to defaults
        self.settings = AppSettings.defaultSettings

        // Attempt to load persisted settings
        do {
            let loadedSettings = try loadSettingsFromDisk()
            self.settings = loadedSettings
        } catch {
            // Handle missing or corrupted settings gracefully by using defaults
            // This is expected behavior on first launch
        }
    }

    /// Ensure the Application Support directory exists
    func ensureDirectoryExists() throws {
        let directoryPath = Self.applicationSupportDirectory.path

        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(
                    at: Self.applicationSupportDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw SettingsError.directoryCreationFailed(error)
            }
        }
    }

    /// Load settings from disk
    /// Returns default settings if file doesn't exist or is corrupted
    /// Task 5.4: Handle migration for new fields
    func loadSettingsFromDisk() throws -> AppSettings {
        let fileURL = Self.settingsFileURL

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return AppSettings.defaultSettings
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let loadedSettings = try decoder.decode(AppSettings.self, from: data)
            return loadedSettings
        } catch let error as DecodingError {
            throw SettingsError.decodingFailed(error)
        } catch {
            throw SettingsError.loadFailed(error)
        }
    }

    /// Save current settings to disk
    /// Task 5.3: Save settings on change
    func saveSettings() throws {
        try ensureDirectoryExists()

        do {
            let data = try encoder.encode(settings)
            try data.write(to: Self.settingsFileURL, options: .atomic)
        } catch {
            throw SettingsError.saveFailed(error)
        }
    }

    /// Update the model unload timeout setting
    func setModelUnloadTimeout(minutes: Int) throws {
        settings.modelUnloadTimeoutMinutes = minutes
        try saveSettings()
    }

    /// Update the launch at login setting
    func setLaunchAtLogin(enabled: Bool) throws {
        settings.launchAtLogin = enabled
        try saveSettings()
    }

    /// Update the default voice setting (Task 5.3)
    func setDefaultVoice(id: String) throws {
        settings.defaultVoiceId = id
        try saveSettings()
    }

    /// Update all settings at once
    func updateSettings(_ newSettings: AppSettings) throws {
        settings = newSettings
        try saveSettings()
    }

    /// Reset settings to defaults
    func resetToDefaults() throws {
        settings = AppSettings.defaultSettings
        try saveSettings()
    }

    /// Check if settings file exists
    var settingsFileExists: Bool {
        fileManager.fileExists(atPath: Self.settingsFileURL.path)
    }

    /// Delete settings file (useful for testing)
    func deleteSettingsFile() throws {
        if settingsFileExists {
            try fileManager.removeItem(at: Self.settingsFileURL)
        }
    }
}
