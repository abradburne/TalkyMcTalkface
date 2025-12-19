import SwiftUI

/// Row view for displaying a single TTS job
/// Task 6.5: Create JobRowView component
struct JobRowView: View {
    let job: TTSJob
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status/Playing indicator
                statusIcon
                    .frame(width: 20)

                // Text preview and voice
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.textPreview)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 8) {
                        Text(job.voiceId ?? "Default")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(job.relativeTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Playing indicator animation
                if isPlaying {
                    PlayingIndicator()
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isPlaying ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: job.status.iconName)
                .foregroundStyle(.secondary)
        case .processing:
            ProgressView()
                .controlSize(.small)
        case .completed:
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: job.status.iconName)
                    .foregroundStyle(.green)
            }
        case .failed:
            Image(systemName: job.status.iconName)
                .foregroundStyle(.red)
        }
    }
}

/// Animated playing indicator
struct PlayingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: isAnimating ? 12 : 4)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Completed - Not Playing") {
    JobRowView(
        job: TTSJob(
            id: "job_1",
            status: .completed,
            text: "Hello, this is a test of the TTS system with some longer text that will be truncated",
            voiceId: "Alice",
            createdAt: Date()
        ),
        isPlaying: false,
        onTap: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Completed - Playing") {
    JobRowView(
        job: TTSJob(
            id: "job_2",
            status: .completed,
            text: "Currently playing audio",
            voiceId: "Bob",
            createdAt: Date().addingTimeInterval(-120)
        ),
        isPlaying: true,
        onTap: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Processing") {
    JobRowView(
        job: TTSJob(
            id: "job_3",
            status: .processing,
            text: "Processing this text...",
            voiceId: "Charlie",
            createdAt: Date()
        ),
        isPlaying: false,
        onTap: {}
    )
    .padding()
    .frame(width: 350)
}
