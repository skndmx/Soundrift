import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if #available(macOS 13.0, *) {
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    } else {
                        let success = SMLoginItemSetEnabled("com.yourapp.Soundrift-LaunchHelper" as CFString, newValue)
                        if !success {
                            launchAtLogin = false
                        }
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