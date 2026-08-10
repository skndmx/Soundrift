import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(AudioManager.hideMicrosoftTeamsAudioKey) private var hideMicrosoftTeamsAudio = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Toggle("Hide Microsoft Teams Audio", isOn: $hideMicrosoftTeamsAudio)
                .onChange(of: hideMicrosoftTeamsAudio) { _, _ in
                    AudioManager.shared.refreshAllDevices()
                }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
} 