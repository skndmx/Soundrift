import SwiftUI
import AppKit

@main
struct TripleSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UserDefaults.standard.register(defaults: [AudioManager.hideMicrosoftTeamsAudioKey: true])
    }

    var body: some Scene {
        WindowGroup("Soundrift", id: "main") {
            MainView()
        }
        .defaultSize(width: 800, height: 560)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            SoundriftMenuBarMenu()
        } label: {
            Label {
                Text("Soundrift")
            } icon: {
                Image("MenuBarIcon")
                    .renderingMode(.template)
            }
            .labelStyle(.iconOnly)
            .background(OpenWindowBridge())
        }
        .menuBarExtraStyle(.menu)

        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .windowList) {
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) { }

            TextEditingCommands()

            CommandGroup(replacing: .appTermination) {
                Button("Quit Soundrift") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

/// Lives in the menu bar extra label so `openWindow` stays available after the main window closes.
private struct OpenWindowBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .showSoundriftMainWindow)) { _ in
                openWindow(id: "main")
            }
    }
}

private struct SoundriftMenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var audioManager = AudioManager.shared

    var body: some View {
        Text("Current Device: \(audioManager.currentDevice?.name ?? "None")")

        Divider()

        Button("Show Main Window") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Soundrift" }) {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }

        Divider()

        Button("Quit Soundrift") {
            NSApp.terminate(nil)
        }
    }
}
