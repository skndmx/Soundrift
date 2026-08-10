import SwiftUI

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
