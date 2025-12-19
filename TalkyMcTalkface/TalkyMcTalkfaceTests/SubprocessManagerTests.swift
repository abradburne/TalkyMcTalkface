import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for Python subprocess management
/// Task 2.1: 2-4 focused tests for subprocess management
struct SubprocessManagerTests {

    // MARK: - Health Check Tests

    /// Test that health check correctly parses server response
    @Test("Health response parses correctly from JSON")
    func testHealthResponseParsing() throws {
        let json = """
        {
            "status": "ok",
            "model_loaded": true,
            "available_voices": ["voice1", "voice2"],
            "version": "0.1.0"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthResponse.self, from: data)

        #expect(response.status == "ok")
        #expect(response.modelLoaded == true)
        #expect(response.availableVoices == ["voice1", "voice2"])
        #expect(response.version == "0.1.0")
    }

    /// Test health response when model is not loaded
    @Test("Health response handles model not loaded state")
    func testHealthResponseModelNotLoaded() throws {
        let json = """
        {
            "status": "ok",
            "model_loaded": false,
            "available_voices": [],
            "version": "0.1.0"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthResponse.self, from: data)

        #expect(response.status == "ok")
        #expect(response.modelLoaded == false)
        #expect(response.availableVoices.isEmpty)
    }

    // MARK: - Subprocess Manager State Tests

    /// Test subprocess manager initial state
    @Test("Subprocess manager starts in correct initial state")
    @MainActor
    func testInitialState() {
        let manager = SubprocessManager()

        #expect(manager.isRunning == false)
        #expect(manager.lastHealthResponse == nil)
        #expect(manager.lastError == nil)
    }

    /// Test server URL configuration
    @Test("Server URL is correctly configured")
    @MainActor
    func testServerConfiguration() {
        #expect(SubprocessManager.serverHost == "127.0.0.1")
        #expect(SubprocessManager.serverPort == 5111)
        #expect(SubprocessManager.healthURL.absoluteString == "http://127.0.0.1:5111/health")
    }
}
