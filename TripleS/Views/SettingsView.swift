import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("How to use")
                    .font(.subheadline)
                    .fontWeight(.medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Check devices to include in your shortcut")
                    Text("2. Tap the eye icon to hide devices you don't need")
                    Text("3. Set keyboard shortcuts in the left sidebar")
                    Text("4. Use the shortcuts to switch between devices")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hidden devices")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Use the eye icon on any device row to hide it. Hidden devices move to the Hidden section at the bottom of the Output or Input tab, where you can unhide them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
