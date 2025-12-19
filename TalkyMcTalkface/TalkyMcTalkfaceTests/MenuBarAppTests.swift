import Testing
@testable import TalkyMcTalkface

/// Tests for menu bar application functionality
/// Task 1.1: 2-4 focused tests for menu bar app functionality
struct MenuBarAppTests {

    // MARK: - Status Icon State Tests

    /// Test that status icon displays correct system image for each state
    @Test("Status icons use correct SF Symbols for each state")
    func testStatusIconNames() {
        #expect(AppStatus.ready.iconName == "checkmark.circle.fill")
        #expect(AppStatus.loading.iconName == "arrow.clockwise.circle.fill")
        #expect(AppStatus.error.iconName == "exclamationmark.triangle.fill")
        #expect(AppStatus.downloadRequired.iconName == "arrow.down.circle.fill")
    }

    /// Test that status descriptions are user-friendly
    @Test("Status descriptions provide meaningful information")
    func testStatusDescriptions() {
        #expect(AppStatus.ready.statusDescription.contains("ready"))
        #expect(AppStatus.loading.statusDescription.contains("Starting"))
        #expect(AppStatus.error.statusDescription.contains("error"))
        #expect(AppStatus.downloadRequired.statusDescription.contains("download"))
    }

    // MARK: - App State Tests

    /// Test that app state can be updated correctly
    @Test("App state updates correctly")
    @MainActor
    func testAppStateUpdates() async {
        let appState = AppState()

        // Initial state should be loading
        #expect(appState.status == .loading)

        // Update to ready
        appState.setStatus(.ready)
        #expect(appState.status == .ready)

        // Update to error
        appState.setStatus(.error)
        #expect(appState.status == .error)

        // Update to download required
        appState.setStatus(.downloadRequired)
        #expect(appState.status == .downloadRequired)
    }

    /// Test that raw values match expected display strings
    @Test("Status raw values are correct for display")
    func testStatusRawValues() {
        #expect(AppStatus.ready.rawValue == "Ready")
        #expect(AppStatus.loading.rawValue == "Loading")
        #expect(AppStatus.error.rawValue == "Error")
        #expect(AppStatus.downloadRequired.rawValue == "Download Required")
    }
}
