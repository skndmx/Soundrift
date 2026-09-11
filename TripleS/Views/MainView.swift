import SwiftUI

enum MainWindowTab: String, CaseIterable, Identifiable {
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

struct MainView: View {
    @StateObject private var hotkeys = HotkeyController()
    @State private var tab: MainWindowTab = .devices
    @State private var deviceKind: DeviceType = .output

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            Group {
                switch tab {
                case .devices:
                    DevicesView(kind: $deviceKind)
                case .shortcuts:
                    ShortcutsView(hotkeys: hotkeys)
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(SoundriftTheme.accent)
        .frame(minWidth: 560, minHeight: 440)
        .onAppear {
            hotkeys.registerAll()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SoundriftTheme.accent)
                    .frame(width: 22, height: 22)
                Text("Soundrift")
                    .font(.headline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Soundrift")

            Spacer(minLength: 16)

            Picker("Section", selection: $tab) {
                ForEach(MainWindowTab.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    MainView()
        .frame(width: SoundriftTheme.windowWidth, height: SoundriftTheme.windowHeight)
}
