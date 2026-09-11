import SwiftUI

struct ShortcutsView: View {
    @ObservedObject var hotkeys: HotkeyController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard shortcuts")
                    .font(.title2.weight(.semibold))
                Text("Global hotkeys work even when Soundrift is in the menu bar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(ShortcutKind.allCases.enumerated()), id: \.element) { index, kind in
                    ShortcutRow(
                        kind: kind,
                        chord: hotkeys.chord(for: kind),
                        isRecording: hotkeys.recordingTarget == kind,
                        errorMessage: hotkeys.error(for: kind),
                        onChange: { hotkeys.beginRecording(kind) },
                        onCancel: { hotkeys.cancelRecording() }
                    )

                    if index < ShortcutKind.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(SoundriftTheme.groupedFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }

            if let message = firstPersistentError {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(SoundriftTheme.accent)
                    .font(.subheadline)
                Text("Tip: avoid shortcuts already used by Zoom, Teams, or Mission Control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var firstPersistentError: String? {
        hotkeys.outputError ?? hotkeys.inputError ?? hotkeys.muteError
    }
}

private struct ShortcutRow: View {
    let kind: ShortcutKind
    let chord: HotkeyChord
    let isRecording: Bool
    let errorMessage: String?
    let onChange: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SoundriftTheme.accent)
                .frame(width: 28, height: 28)

            Text(kind.title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            HotkeyKeycaps(chord: chord)

            if isRecording {
                Text("Recording… press keys")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.leading, 4)

                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                Button("Change", action: onChange)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 52)
        .background(isRecording ? SoundriftTheme.recordingFill : Color.clear)
        .help(errorMessage ?? "Record a new shortcut for \(kind.title.lowercased())")
    }
}

struct HotkeyKeycaps: View {
    let chord: HotkeyChord

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(chord.tokens.enumerated()), id: \.offset) { _, token in
                Keycap(glyph: token)
            }
        }
    }
}

struct Keycap: View {
    let glyph: String

    var body: some View {
        Text(glyph)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(minWidth: glyph.count > 1 ? 44 : 26, minHeight: 26)
            .padding(.horizontal, glyph.count > 1 ? 6 : 0)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
    }
}
