import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for Settings UI
struct SettingsUITests {

    /// Test SettingsView requires all options in AppSettings
    @Test("AppSettings contains all required fields for SettingsView")
    func testAppSettingsContainsRequiredFields() {
        let settings = AppSettings.defaultSettings

        // Verify all required fields exist
        #expect(settings.launchAtLogin == false)
        #expect(settings.defaultVoiceId == nil)
        #expect(settings.modelUnloadTimeoutMinutes == 0)
    }

    /// Test launch at login setting updates correctly
    @Test("Launch at login setting persists")
    func testLaunchAtLoginPersists() throws {
        let settings = AppSettings(
            modelUnloadTimeoutMinutes: 0,
            launchAtLogin: true
        )

        #expect(settings.launchAtLogin == true)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(settings)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded.launchAtLogin == true)
    }

    /// Test default voice setting persists
    @Test("Default voice setting persists")
    func testDefaultVoicePersists() throws {
        let settings = AppSettings(
            modelUnloadTimeoutMinutes: 0,
            launchAtLogin: false,
            defaultVoiceId: "test-voice"
        )

        #expect(settings.defaultVoiceId == "test-voice")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(settings)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded.defaultVoiceId == "test-voice")
    }
}
