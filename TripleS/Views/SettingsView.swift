import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding(.bottom)
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    if #available(macOS 13.0, *) {
                        try? SMAppService.mainApp.register()
                    } else {
                        let success = SMLoginItemSetEnabled("com.yourapp.TripleS-LaunchHelper" as CFString, newValue)
                        if !success {
                            launchAtLogin = false
                        }
                    }
                }
        }
        .padding()
        .frame(width: 300, height: 100)
    }
}

#Preview {
    SettingsView()
} 