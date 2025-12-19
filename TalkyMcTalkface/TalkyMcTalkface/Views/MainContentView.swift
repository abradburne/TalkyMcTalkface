import SwiftUI
import AppKit

/// Main content view combining all TTS components
/// Task 6.8: Create MainContentView
struct MainContentView: View {
    @ObservedObject var appState: AppState

    /// Timer for polling jobs list
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text input section
            TextInputView(
                text: $appState.currentInputText,
                isDisabled: appState.isGenerating
            )

            // Voice picker
            VoicePicker(
                voices: appState.voices,
                selectedVoiceId: Binding(
                    get: { appState.selectedVoiceId },
                    set: { newValue in
                        if let id = newValue {
                            appState.updateDefaultVoice(id: id)
                        }
                    }
                ),
                isDisabled: appState.isGenerating
            )

            // Generate button
            GenerateButton(
                isGenerating: appState.isGenerating,
                isDisabled: appState.currentInputText.isEmpty || appState.selectedVoiceId == nil,
                action: {
                    Task {
                        await appState.generateSpeech()
                    }
                }
            )

            Divider()

            // Jobs list
            JobsListView(
                jobs: appState.jobs,
                currentPlayingJobId: appState.currentPlayingJobId,
                onPlayJob: { jobId in
                    Task {
                        await appState.playJob(id: jobId)
                    }
                },
                onDownloadJob: { jobId in
                    Task {
                        await downloadAudio(jobId: jobId)
                    }
                },
                onDeleteJob: { jobId in
                    Task {
                        await appState.deleteJob(id: jobId)
                    }
                },
                onDeleteAll: {
                    Task {
                        await appState.deleteAllJobs()
                    }
                }
            )
        }
        .onAppear {
            startPolling()
            Task {
                await appState.refreshJobs()
            }
        }
        .onDisappear {
            stopPolling()
        }
    }

    /// Start polling for jobs updates
    /// Task 6.10: Poll GET /jobs every 2-3 seconds while popover is visible
    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            Task { @MainActor in
                await appState.refreshJobs()
            }
        }
    }

    /// Stop polling
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Download audio for a job using NSSavePanel
    /// Task 6.7: Implement audio download flow
    private func downloadAudio(jobId: String) async {
        do {
            let audioData = try await appState.getAudioData(jobId: jobId)

            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.wav, .audio]
                savePanel.nameFieldStringValue = "tts_\(jobId).wav"
                savePanel.title = "Save Audio"
                savePanel.message = "Choose where to save the audio file"

                if savePanel.runModal() == .OK, let url = savePanel.url {
                    do {
                        try audioData.write(to: url)
                    } catch {
                        print("Failed to save audio: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Failed to download audio: \(error.localizedDescription)")
        }
    }
}

#Preview {
    MainContentView(appState: {
        let state = AppState()
        state.setStatus(.ready)
        return state
    }())
    .padding()
    .frame(width: 380)
}
