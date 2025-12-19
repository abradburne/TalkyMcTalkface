import SwiftUI

/// Multi-line text input for TTS text
/// Task 6.2: Create TextInputView component
struct TextInputView: View {
    @Binding var text: String
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Text to speak")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .disabled(isDisabled)

                // Placeholder text
                if text.isEmpty {
                    Text("Enter text to convert to speech...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 100, maxHeight: 140)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TextInputView(text: .constant(""), isDisabled: false)
        TextInputView(text: .constant("Hello, world!"), isDisabled: false)
        TextInputView(text: .constant("Disabled state"), isDisabled: true)
    }
    .padding()
    .frame(width: 350)
}
