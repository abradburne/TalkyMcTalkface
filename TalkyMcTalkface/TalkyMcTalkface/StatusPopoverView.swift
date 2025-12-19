import SwiftUI

/// View displayed when user clicks on the menu bar icon
/// Task 3.3: Build "Download Required" UI state
/// Task 3.5: Add download progress UI
/// Task 6.9: Update StatusPopoverView to show MainContentView when ready
struct StatusPopoverView: View {
    @ObservedObject var appState: AppState
    @State private var hasStartedBackend = false
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header with settings toggle
            headerView

            Divider()

            // Content based on current status and settings toggle
            if showingSettings {
                SettingsView(appState: appState)
            } else {
                statusContent
            }

            // Error message when in error state
            if appState.status == .error, let errorMessage = appState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            // Controls
            footerView
        }
        .padding()
        .frame(width: showingSettings ? 420 : 380) // Wider for settings
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: showingSettings)
        .task {
            // Task 2.2: Start backend when app launches
            if !hasStartedBackend {
                hasStartedBackend = true
                await appState.startBackend()
            }
        }
    }

    /// Header view with status and settings toggle
    /// Task 7.3: Add settings toggle to StatusPopoverView
    private var headerView: some View {
        HStack {
            if showingSettings {
                // Back button when in settings
                Button {
                    showingSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Spacer()

                Text("Settings")
                    .font(.headline)

                Spacer()

                // Invisible spacer to balance the back button
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.body)
                .opacity(0)
            } else {
                Image(systemName: appState.status.iconName)
                    .foregroundStyle(statusColor)
                    .font(.title2)
                Text(appState.status.rawValue)
                    .font(.headline)

                Spacer()

                // Settings button
                if appState.status == .ready {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings")
                }
            }
        }
    }

    /// Footer view with quit button
    private var footerView: some View {
        HStack {
            Spacer()
            Button("Quit") {
                quitApplication()
            }
            .keyboardShortcut("q")
        }
    }

    /// Content view that changes based on app status
    /// Task 3.3, 3.5: Different UI for download required vs downloading
    /// Task 6.9: Show MainContentView when status is .ready
    @ViewBuilder
    private var statusContent: some View {
        switch appState.status {
        case .ready:
            MainContentView(appState: appState)
        case .downloadRequired:
            downloadRequiredView
        case .downloading:
            downloadingView
        case .loading:
            loadingView
        case .error:
            errorView
        }
    }

    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Starting TalkyMcTalkface...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// Error view
    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("An error occurred")
                .font(.body)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task {
                    await appState.startBackend()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// View displayed when model download is required
    /// Task 3.3: Display explanatory text about model requirement
    private var downloadRequiredView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Download Required")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("TalkyMcTalkface requires a text-to-speech model to generate speech. This is a one-time download.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Download size information
            HStack {
                Image(systemName: "arrow.down.doc")
                    .foregroundStyle(.orange)
                Text("Approximate size: 1-2 GB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Download button
            Button(action: {
                Task {
                    await appState.startModelDownload()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("Download Model")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    /// View displayed during model download
    /// Task 3.5: Display progress bar with percentage/bytes downloaded
    private var downloadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloading Model...")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Status message from download service
            Text(appState.modelDownloadService.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: appState.modelDownloadService.progress)
                    .progressViewStyle(.linear)

                // Progress details
                HStack {
                    Text(appState.modelDownloadService.formattedProgress)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.modelDownloadService.formattedPercentage)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }

            // Cancel button
            Button(action: {
                appState.cancelModelDownload()
            }) {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var statusColor: Color {
        switch appState.status {
        case .ready:
            return .green
        case .loading:
            return .blue
        case .error:
            return .red
        case .downloadRequired:
            return .orange
        case .downloading:
            return .blue
        }
    }

    /// Task 2.4: Graceful shutdown when quitting
    private func quitApplication() {
        Task {
            await appState.stopBackend()
            await MainActor.run {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

#Preview("Ready") {
    StatusPopoverView(appState: {
        let state = AppState()
        state.setStatus(.ready)
        return state
    }())
}

#Preview("Loading") {
    StatusPopoverView(appState: {
        let state = AppState()
        state.setStatus(.loading)
        return state
    }())
}

#Preview("Download Required") {
    StatusPopoverView(appState: {
        let state = AppState()
        state.setStatus(.downloadRequired)
        return state
    }())
}

#Preview("Downloading") {
    StatusPopoverView(appState: {
        let state = AppState()
        state.setStatus(.downloading)
        return state
    }())
}

#Preview("Error") {
    StatusPopoverView(appState: {
        let state = AppState()
        state.setStatus(.error)
        state.errorMessage = "Failed to connect to backend"
        return state
    }())
}
