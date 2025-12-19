import SwiftUI

/// Button to trigger TTS generation
/// Task 6.4: Create GenerateButton component
struct GenerateButton: View {
    let isGenerating: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "play.fill")
                }
                Text(isGenerating ? "Generating..." : "Generate Speech")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isDisabled || isGenerating)
        .keyboardShortcut(.return, modifiers: .command)
    }

    /// Computed disabled state helper
    var buttonDisabled: Bool {
        isDisabled || isGenerating
    }
}

#Preview("Normal") {
    GenerateButton(
        isGenerating: false,
        isDisabled: false,
        action: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Generating") {
    GenerateButton(
        isGenerating: true,
        isDisabled: false,
        action: {}
    )
    .padding()
    .frame(width: 350)
}

#Preview("Disabled") {
    GenerateButton(
        isGenerating: false,
        isDisabled: true,
        action: {}
    )
    .padding()
    .frame(width: 350)
}
