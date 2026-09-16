import SwiftUI
import AppKit

@main
struct TripleSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        UserDefaults.standard.register(defaults: [AudioManager.hideMicrosoftTeamsAudioKey: true])
    }

    var body: some Scene {
        // Hidden extra: Scene for .commands without a second status item.
        // AppDelegate owns the window and the visible NSStatusItem switcher.
        // No Window/WindowGroup — close/reopen must not spawn duplicates.
        MenuBarExtra(isInserted: .constant(false)) {
            EmptyView()
        } label: {
            EmptyView()
        }
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
