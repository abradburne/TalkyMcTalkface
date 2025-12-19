import Testing
import Foundation
@testable import TalkyMcTalkface

/// Tests for first-launch model download experience
/// Task 3.1: 2-4 focused tests for download functionality
struct ModelDownloadTests {

    // MARK: - Download State Detection Tests

    /// Test that app detects "Download Required" state when model is not loaded
    @Test("Download required state detected when model not loaded")
    func testDownloadRequiredStateDetection() throws {
        // Simulated health response with model_loaded = false
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

        #expect(response.modelLoaded == false)
        #expect(response.status == "ok")
    }

    /// Test that app detects "Ready" state when model is loaded
    @Test("Ready state detected when model is loaded")
    func testReadyStateDetection() throws {
        // Simulated health response with model_loaded = true
        let json = """
        {
            "status": "ok",
            "model_loaded": true,
            "available_voices": ["voice1"],
            "version": "0.1.0"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(HealthResponse.self, from: data)

        #expect(response.modelLoaded == true)
        #expect(response.status == "ok")
    }

    // MARK: - Download Progress Tests

    /// Test download progress response parsing
    @Test("Download progress response parses correctly")
    func testDownloadProgressParsing() throws {
        let json = """
        {
            "status": "downloading",
            "progress": 0.45,
            "downloaded_bytes": 450000000,
            "total_bytes": 1000000000,
            "message": "Downloading model files..."
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(ModelDownloadProgress.self, from: data)

        #expect(response.status == "downloading")
        #expect(response.progress == 0.45)
        #expect(response.downloadedBytes == 450000000)
        #expect(response.totalBytes == 1000000000)
        #expect(response.message == "Downloading model files...")
    }

    /// Test download completion response parsing
    @Test("Download completion response parses correctly")
    func testDownloadCompletionParsing() throws {
        let json = """
        {
            "status": "completed",
            "progress": 1.0,
            "downloaded_bytes": 1000000000,
            "total_bytes": 1000000000,
            "message": "Model download complete"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(ModelDownloadProgress.self, from: data)

        #expect(response.status == "completed")
        #expect(response.progress == 1.0)
        #expect(response.isComplete)
    }

    // MARK: - Model Download Service Tests

    /// Test ModelDownloadService initial state
    @Test("ModelDownloadService starts in correct initial state")
    @MainActor
    func testModelDownloadServiceInitialState() {
        let service = ModelDownloadService()

        #expect(service.isDownloading == false)
        #expect(service.progress == 0.0)
        #expect(service.downloadedBytes == 0)
        #expect(service.totalBytes == 0)
        #expect(service.errorMessage == nil)
    }

    /// Test download URL configuration
    @Test("Download endpoint URL is correctly configured")
    @MainActor
    func testDownloadURLConfiguration() {
        #expect(ModelDownloadService.downloadURL.absoluteString == "http://127.0.0.1:5111/model/download")
        #expect(ModelDownloadService.progressURL.absoluteString == "http://127.0.0.1:5111/model/progress")
    }
}
