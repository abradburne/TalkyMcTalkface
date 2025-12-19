import SwiftUI

@main
struct TalkyMcTalkfaceApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            StatusPopoverView(appState: appState)
        } label: {
            MenuBarIconView(status: appState.status)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // Start backend when app launches
        // Note: We use the AppDelegate for lifecycle management
    }
}

/// App delegate for handling application lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Get reference to app state from the SwiftUI app
        // The backend will be started by the StatusPopoverView on appear
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Graceful shutdown on app quit
        // The subprocess manager's stop() is called via the app state
    }
}
