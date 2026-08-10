//
//  TripleSApp.swift
//  TripleS
//
//  Created by kevin on 11/1/24.
//

import SwiftUI

@main
struct TripleSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        UserDefaults.standard.register(defaults: [AudioManager.hideMicrosoftTeamsAudioKey: true])
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // Standard window commands
            CommandGroup(replacing: .windowList) {
                Button("Close") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            // Standard file menu commands
            CommandGroup(replacing: .newItem) { }
            
            // Standard edit menu commands
            TextEditingCommands()
            
            // App termination commands
            CommandGroup(replacing: .appTermination) {
                Button("Quit Soundrift") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
    