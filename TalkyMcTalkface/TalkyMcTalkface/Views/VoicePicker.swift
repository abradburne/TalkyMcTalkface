import SwiftUI

/// Dropdown picker for selecting a TTS voice
/// Task 6.3: Create VoicePicker component
struct VoicePicker: View {
    let voices: [Voice]
    @Binding var selectedVoiceId: String?
    let isDisabled: Bool

    var body: some View {
        HStack {
            Text("Voice")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Voice", selection: $selectedVoiceId) {
                if voices.isEmpty {
                    Text("Loading...").tag(nil as String?)
                } else {
                    ForEach(voices) { voice in
                        Text(voice.name).tag(voice.id as String?)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(isDisabled || voices.isEmpty)
            .frame(maxWidth: 200)
        }
    }
}

#Preview("With Voices") {
    VoicePicker(
        voices: [
            Voice(id: "voice_1", name: "Alice"),
            Voice(id: "voice_2", name: "Bob"),
            Voice(id: "voice_3", name: "Charlie")
        ],
        selectedVoiceId: .constant("voice_1"),
        isDisabled: false
    )
    .padding()
    .frame(width: 350)
}

#Preview("Empty") {
    VoicePicker(
        voices: [],
        selectedVoiceId: .constant(nil),
        isDisabled: false
    )
    .padding()
    .frame(width: 350)
}
