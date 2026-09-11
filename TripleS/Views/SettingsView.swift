import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("General")
                        .font(.headline)

                    GroupedDeviceList {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .padding(.horizontal, 12)
                            .frame(minHeight: SoundriftTheme.rowHeight)
                            .onChange(of: launchAtLogin) { _, newValue in
                                if newValue {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                    }

                    Text("Soundrift stays in the menu bar. Close the window to hide the Dock icon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)

                    GroupedDeviceList {
                        settingsInfoRow(label: "Version", value: SoundriftTheme.appVersion)
                        Divider()
                            .padding(.leading, 12)
                        settingsInfoRow(label: "Created by", value: "Kevin Jin")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)

                    GroupedDeviceList {
                        VStack(alignment: .leading, spacing: 8) {
                            tipRow("Check devices to include them in shortcut rotation.")
                            tipRow("Click a device name to switch to it immediately.")
                            tipRow("Hide unused devices with the eye icon; restore them from Hidden.")
                            tipRow("Record global shortcuts in the Shortcuts tab.")
                            tipRow("Use the mute shortcut or menu bar item to mute the microphone.")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: SoundriftTheme.rowHeight)
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
        .frame(width: SoundriftTheme.windowWidth, height: SoundriftTheme.windowHeight)
}
