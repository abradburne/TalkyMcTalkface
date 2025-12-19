import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for extended settings (default voice)
struct ExtendedSettingsTests {

    /// Test default voice persistence
    @Test("Default voice ID persists in settings")
    func testDefaultVoicePersistence() throws {
        let settings = AppSettings(
            modelUnloadTimeoutMinutes: 0,
            launchAtLogin: false,
            defaultVoiceId: "voice_123"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(settings)
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded.defaultVoiceId == "voice_123")
    }

    /// Test settings migration for new fields (old settings without new fields)
    @Test("Old settings without new fields load with defaults")
    func testSettingsMigration() throws {
        // Simulating old settings JSON without new fields
        let oldJson = """
        {
            "modelUnloadTimeoutMinutes": 30,
            "launchAtLogin": true
        }
        """

        let data = oldJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        let settings = try decoder.decode(AppSettings.self, from: data)

        // Old values preserved
        #expect(settings.modelUnloadTimeoutMinutes == 30)
        #expect(settings.launchAtLogin == true)

        // New fields default to nil
        #expect(settings.defaultVoiceId == nil)
    }
}
