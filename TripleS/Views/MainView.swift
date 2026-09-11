import SwiftUI
import AppKit

struct MainView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var hotkeys = HotkeyController()
    @State private var selectedTab: MainTab = .devices

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            Divider().opacity(0.45)
            tabContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(SoundriftTheme.accent)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            hotkeys.registerAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if hotkeys.recordingTarget != nil {
                hotkeys.cancelRecording()
            }
        }
    }

    private var titlebar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                SoundriftBrandMark(size: 24)
                Text("Soundrift")
                    .font(.title3.weight(.semibold))
            }

            Spacer(minLength: 12)

            Picker("Section", selection: $selectedTab) {
                ForEach(MainTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 292)
            .labelsHidden()
        }
        .padding(.leading, 78)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .devices:
            DevicesView(audioManager: audioManager)
        case .shortcuts:
            ShortcutsView(hotkeys: hotkeys)
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MainView()
        .frame(width: 720, height: 540)
}
