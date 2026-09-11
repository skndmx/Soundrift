import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsGroup(title: "General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            if newValue {
                                try? SMAppService.mainApp.register()
                            } else {
                                try? SMAppService.mainApp.unregister()
                            }
                        }
                }

                settingsGroup(title: "How to use") {
                    VStack(alignment: .leading, spacing: 8) {
                        howToRow(number: 1, text: "Check devices to include in shortcut rotation.")
                        howToRow(number: 2, text: "Click a device name to switch to it; use the eye icon to hide clutter.")
                        howToRow(number: 3, text: "Record global hotkeys in the Shortcuts tab.")
                        howToRow(number: 4, text: "Use those shortcuts to cycle devices from anywhere.")
                    }
                }

                settingsGroup(title: "Hidden devices") {
                    Text("Hidden devices move to the Hidden section at the bottom of Devices. They stay out of shortcut rotation until you unhide them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsGroup(title: "About") {
                    LabeledContent("Version", value: versionString)
                    LabeledContent("Created by", value: "Kevin Jin")
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let versionParts = version.split(separator: ".")
        if build == "0" || build.isEmpty {
            return versionParts.count >= 3 ? version : "\(version).0"
        }
        return "\(version).\(build)"
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SoundriftTheme.groupedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func howToRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(SoundriftTheme.accent.opacity(0.85), in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 720, height: 540)
        .preferredColorScheme(.dark)
}
