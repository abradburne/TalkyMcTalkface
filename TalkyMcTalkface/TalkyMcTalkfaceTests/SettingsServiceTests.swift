import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for settings infrastructure functionality
/// Task 5.1: 2-4 focused tests for settings functionality
struct SettingsServiceTests {

    // MARK: - Settings File Creation Tests

    /// Test that settings file is created in the correct location
    @Test("Settings file is created in Application Support directory")
    @MainActor
    func testSettingsFileCreation() async throws {
        let service = SettingsService()

        // Clean up any existing settings file
        try? service.deleteSettingsFile()

        // Save settings should create the file
        try service.saveSettings()

        // Verify file exists
        #expect(service.settingsFileExists)

        // Verify path is in Application Support
        let path = SettingsService.settingsFileURL.path
        #expect(path.contains("Library/Application Support/TalkyMcTalkface"))
        #expect(path.hasSuffix("Settings.json"))

        // Clean up
        try? service.deleteSettingsFile()
    }

    // MARK: - Settings Load on App Launch Tests

    /// Test that settings load correctly on initialization
    @Test("Settings load on app launch")
    @MainActor
    func testSettingsLoadOnLaunch() async throws {
        // Create a service and save custom settings
        let service1 = SettingsService()
        try? service1.deleteSettingsFile()

        let customSettings = AppSettings(
            modelUnloadTimeoutMinutes: 30,
            launchAtLogin: true
        )
        try service1.updateSettings(customSettings)

        // Create a new service (simulating app relaunch)
        let service2 = SettingsService()

        // Verify settings were loaded
        #expect(service2.settings.modelUnloadTimeoutMinutes == 30)
        #expect(service2.settings.launchAtLogin == true)

        // Clean up
        try? service2.deleteSettingsFile()
    }

    // MARK: - Settings Save on Change Tests

    /// Test that settings are saved when changed
    @Test("Settings save on change")
    @MainActor
    func testSettingsSaveOnChange() async throws {
        let service = SettingsService()

        // Clean up any existing settings file
        try? service.deleteSettingsFile()

        // Change a setting (this should save automatically)
        try service.setModelUnloadTimeout(minutes: 15)

        // Verify file exists
        #expect(service.settingsFileExists)

        // Load raw JSON to verify content
        let data = try Data(contentsOf: SettingsService.settingsFileURL)
        let loadedSettings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(loadedSettings.modelUnloadTimeoutMinutes == 15)

        // Clean up
        try? service.deleteSettingsFile()
    }

    // MARK: - Graceful Handling of Missing/Corrupted Settings

    /// Test that missing settings file is handled gracefully with defaults
    @Test("Missing settings file uses defaults")
    @MainActor
    func testMissingSettingsUsesDefaults() async throws {
        // Create service and ensure no settings file exists
        let service = SettingsService()
        try? service.deleteSettingsFile()

        // Reinitialize to simulate fresh start
        let freshService = SettingsService()

        // Should use default values
        #expect(freshService.settings.modelUnloadTimeoutMinutes == 0)
        #expect(freshService.settings.launchAtLogin == false)
    }
}
