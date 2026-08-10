import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)

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
