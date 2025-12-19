import SwiftUI
import AppKit

/// List view for displaying TTS jobs with context menus
/// Task 6.6: Create JobsListView component
struct JobsListView: View {
    let jobs: [TTSJob]
    let currentPlayingJobId: String?
    let onPlayJob: (String) -> Void
    let onDownloadJob: (String) -> Void
    let onDeleteJob: (String) -> Void
    let onDeleteAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("History")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !jobs.isEmpty {
                    Text("\(jobs.count) job\(jobs.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if jobs.isEmpty {
                emptyStateView
            } else {
                jobsList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.title)
                .foregroundStyle(.tertiary)
            Text("No jobs yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Generate speech to see it here")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var jobsList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(jobs) { job in
                        JobRowView(
                            job: job,
                            isPlaying: currentPlayingJobId == job.id,
                            onTap: { onPlayJob(job.id) }
                        )
                        .contextMenu {
                            if job.status == .completed {
                                Button {
                                    onPlayJob(job.id)
                                } label: {
                                    Label("Play", systemImage: "play.fill")
                                }

                                Button {
                                    onDownloadJob(job.id)
                                } label: {
                                    Label("Download Audio", systemImage: "arrow.down.circle")
                                }

                                Divider()
                            }

                            Button(role: .destructive) {
                                onDeleteJob(job.id)
                            } label: {
                                Label("Delete Job", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 250)

            // Delete All button
            if jobs.count > 1 {
                Divider()
                    .padding(.vertical, 4)

                Button(role: .destructive) {
                    onDeleteAll()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }
}

#Preview("With Jobs") {
    JobsListView(
        jobs: [
            TTSJob(id: "job_1", status: .completed, text: "Hello world", voiceId: "Alice", createdAt: Date()),
            TTSJob(id: "job_2", status: .completed, text: "This is a longer text that demonstrates truncation", voiceId: "Bob", createdAt: Date().addingTimeInterval(-300)),
            TTSJob(id: "job_3", status: .processing, text: "Processing...", voiceId: "Charlie", createdAt: Date().addingTimeInterval(-10)),
        ],
        currentPlayingJobId: "job_1",
        onPlayJob: { _ in },
        onDownloadJob: { _ in },
        onDeleteJob: { _ in },
        onDeleteAll: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Empty") {
    JobsListView(
        jobs: [],
        currentPlayingJobId: nil,
        onPlayJob: { _ in },
        onDownloadJob: { _ in },
        onDeleteJob: { _ in },
        onDeleteAll: {}
    )
    .padding()
    .frame(width: 350)
}
