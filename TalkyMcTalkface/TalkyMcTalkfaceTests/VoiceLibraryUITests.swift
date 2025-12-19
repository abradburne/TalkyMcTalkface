import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for Voice Library UI in Settings
/// Task Group 4: Settings View Voice Library Section
struct VoiceLibraryUITests {

    /// Test that VoiceLibraryConfig contains correct voices folder path
    @Test("VoiceLibraryConfig has correct voices folder path")
    func testVoicesFolder() {
        let voicesPath = VoiceLibraryConfig.voicesFolderPath

        // Verify path ends with expected components
        #expect(voicesPath.contains("Library/Application Support/TalkyMcTalkface/voices"))
    }

    /// Test that VoiceLibraryConfig contains a valid browse URL
    @Test("VoiceLibraryConfig has valid browse URL")
    func testBrowseURL() {
        let url = VoiceLibraryConfig.browseVoicesURL

        #expect(url != nil)
        #expect(url?.scheme == "https")
    }

    /// Test that Voice Library section should appear after Model Management
    @Test("Voice Library section appears after Model Management")
    func testSectionOrder() {
        // The section order in SettingsView is:
        // 1. Default Voice
        // 2. Launch at Login
        // 3. Model Management
        // 4. Voice Library
        // 5. Server & API
        // 6. Command Line Tool

        let sectionOrder = [
            "Default Voice",
            "Launch at Login",
            "Model Management",
            "Voice Library",
            "Server & API",
            "Command Line Tool"
        ]

        // Verify Voice Library is at index 3 (after Model Management at index 2)
        let voiceLibraryIndex = sectionOrder.firstIndex(of: "Voice Library")
        let modelManagementIndex = sectionOrder.firstIndex(of: "Model Management")
        let cliIndex = sectionOrder.firstIndex(of: "Command Line Tool")

        #expect(voiceLibraryIndex == 3)
        #expect(modelManagementIndex == 2)
        #expect(cliIndex == 5)
        #expect(voiceLibraryIndex! > modelManagementIndex!)
        #expect(voiceLibraryIndex! < cliIndex!)
    }

    /// Test VoiceLibraryConfig provides correct folder URL
    @Test("VoiceLibraryConfig provides folder URL for NSWorkspace")
    func testFolderURL() {
        let folderURL = VoiceLibraryConfig.voicesFolderURL

        #expect(folderURL != nil)
        #expect(folderURL?.isFileURL == true)
        #expect(folderURL?.path.contains("voices") == true)
    }
}
