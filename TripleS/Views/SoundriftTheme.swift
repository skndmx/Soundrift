import SwiftUI

enum SoundriftTheme {
    /// System Settings–like indigo (~#5E5CE6).
    static let accent = Color(red: 94 / 255, green: 92 / 255, blue: 230 / 255)
    static let heroFill = accent.opacity(0.22)
    static let activeRowFill = accent.opacity(0.20)
    static let rowFill = Color.primary.opacity(0.06)
    static let recordingFill = Color.red.opacity(0.14)
    static let groupedFill = Color.primary.opacity(0.06)
    static let rowHeight: CGFloat = 44
}

struct SoundriftBrandMark: View {
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(SoundriftTheme.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

enum MainTab: String, CaseIterable, Identifiable {
    case devices
    case shortcuts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: "Devices"
        case .shortcuts: "Shortcuts"
        case .settings: "Settings"
        }
    }
}

enum ShortcutKind: String, CaseIterable, Identifiable {
    case output
    case input
    case mute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .output: "Cycle output devices"
        case .input: "Cycle input devices"
        case .mute: "Mute microphone"
        }
    }

    var iconName: String {
        switch self {
        case .output: "speaker.wave.2.fill"
        case .input: "mic.fill"
        case .mute: "mic.slash.fill"
        }
    }
}
