import SwiftUI
import AppKit

@main
struct TripleSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UserDefaults.standard.register(defaults: [AudioManager.hideMicrosoftTeamsAudioKey: true])
    }

    var body: some Scene {
        // MenuBarExtra first: no SwiftUI Window/WindowGroup scene, so close/reopen
        // cannot spawn duplicate windows. AppDelegate owns the single NSWindow.
        MenuBarExtra {
            SoundriftMenuBarMenu {
                appDelegate.requestShowMainWindow()
            }
        } label: {
            // Match NSStatusItem sizing (squareLength ~18pt). Plain Image/Label
            // in MenuBarExtra otherwise renders the asset smaller.
            Image(nsImage: menuBarIconImage)
                .resizable()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            // Close lives in File (system saveItem group), which owns ⌘W on macOS.
            CommandGroup(replacing: .saveItem) {
                Button("Close") {
                    (NSApp.delegate as? AppDelegate)?.hideMainWindow()
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

private var menuBarIconImage: NSImage {
    let image = NSImage(named: "MenuBarIcon") ?? NSImage(size: NSSize(width: 18, height: 18))
    image.isTemplate = true
    image.size = NSSize(width: 18, height: 18)
    return image
}

private struct SoundriftMenuBarMenu: View {
    let showMainWindow: () -> Void

    var body: some View {
        // Don't observe AudioManager here. MenuBarExtra(.menu) rebuilds the
        // NSMenu on every @Published change, which eats the Show Main Window click.
        Text("Current Device: \(AudioDevice.getCurrentDefault()?.name ?? "None")")

        Divider()

        Button(muteMicrophoneTitle) {
            DeviceSwitchManager.shared.toggleMicrophoneMute()
        }

        Divider()

        Button("Show Main Window", action: showMainWindow)

        Divider()

        Button("Quit Soundrift") {
            NSApp.terminate(nil)
        }
    }

    private var muteMicrophoneTitle: String {
        AudioManager.shared.isCurrentInputMuted() ? "Unmute Microphone" : "Mute Microphone"
    }
}
