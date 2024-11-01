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
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandMenu("Triple S") {
                Button("Quit Triple S") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
