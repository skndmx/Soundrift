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
        .background(.clear)
        .tint(SoundriftTheme.accent)
        .frame(minWidth: 560, minHeight: 440)
        .onAppear {
            hotkeys.registerAll()
        }
    }

    /// Brand + tabs sit below the real titlebar. That strip still looks like
    /// the same glass, but it is the only region that moves the window.
    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image("AppIcon2")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Soundrift")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Soundrift")
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Picker("Section", selection: $tab) {
                ForEach(MainWindowTab.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainView()
        .frame(width: SoundriftTheme.windowWidth, height: SoundriftTheme.windowHeight)
}
