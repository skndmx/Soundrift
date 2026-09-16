import SwiftUI

struct ShortcutsView: View {
    @ObservedObject var hotkeys: HotkeyController

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard shortcuts")
                        .font(.title2.weight(.semibold))
                    Text("Global hotkeys work even when Soundrift is in the menu bar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    shortcutRow(
                        icon: "speaker.wave.2",
                        title: "Cycle output devices",
                        target: .output,
                        keycaps: hotkeys.outputKeycaps
                    )
                    Divider().padding(.leading, 44)
                    shortcutRow(
                        icon: "mic",
                        title: "Cycle input devices",
                        target: .input,
                        keycaps: hotkeys.inputKeycaps
                    )
                    Divider().padding(.leading, 44)
                    shortcutRow(
                        icon: "mic.slash",
                        title: "Mute microphone",
                        target: .mute,
                        keycaps: hotkeys.muteKeycaps
                    )
                }
                .soundriftGlassCard()

                if let message = visibleError {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(SoundriftTheme.recordingRed)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(SoundriftTheme.accentOnGlass)
                        .font(.system(size: 13, weight: .medium))
                    Text("Tip: avoid shortcuts already used by MacOS or other apps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            }
        }
    }

    private var visibleError: String? {
        hotkeys.outputError ?? hotkeys.inputError ?? hotkeys.muteError
    }

    private func shortcutRow(
        icon: String,
        title: String,
        target: HotkeyAssignment,
        keycaps: [String]
    ) -> some View {
        let isRecording = hotkeys.recordingTarget == target

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SoundriftTheme.accentOnGlass)
                .frame(width: 22, height: 22)

            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            HotkeyKeycapStack(symbols: keycaps)

            if isRecording {
                Text("Recording… press keys")
                    .font(.subheadline)
                    .foregroundStyle(SoundriftTheme.recordingRed)
                Button("Cancel") {
                    hotkeys.stopRecording()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(SoundriftTheme.recordingRed)
            } else {
                Button("Change") {
                    hotkeys.beginRecording(target)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(isRecording ? SoundriftTheme.recordingRed.opacity(0.12) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isRecording)
    }
}

struct HotkeyKeycapStack: View {
    let symbols: [String]

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 6)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                }
            }
        }
        .accessibilityLabel(symbols.joined())
    }
}
