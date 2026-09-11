import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            } footer: {
                Text("Soundrift stays in the menu bar. Close the window to hide the Dock icon.")
            }

            Section("About") {
                LabeledContent("Version", value: SoundriftTheme.appVersion)
                LabeledContent("Created by", value: "Kevin Jin")
            }

            Section {
                DisclosureGroup("Tips") {
                    VStack(alignment: .leading, spacing: 6) {
                        tipRow("Check devices to include them in shortcut rotation.")
                        tipRow("Click a device name to switch to it immediately.")
                        tipRow("Hide unused devices with the eye icon; restore them from Hidden.")
                        tipRow("Record global shortcuts in the Shortcuts tab.")
                    }
                    .padding(.top, 4)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
    }

    private func tipRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 640, height: 480)
}
