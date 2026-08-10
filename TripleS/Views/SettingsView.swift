import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage(DeviceAutomationStore.bluetoothReconnectIntervalKey)
    private var bluetoothReconnectInterval = DeviceAutomationStore.defaultBluetoothReconnectInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Auto-switch when connected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("In the Output or Input tab, tap the bolt icon on a device and enable auto-switch. When that device connects, Soundrift sets it as the system default and sends a notification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Auto-reconnect Bluetooth")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("For company Macs or devices without Apple ID, enable auto-reconnect on a paired device (e.g. AirPods). Pair the device once in System Settings → Bluetooth first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Retry every", selection: $bluetoothReconnectInterval) {
                    ForEach(DeviceAutomationStore.bluetoothReconnectIntervalOptions, id: \.self) { interval in
                        Text(intervalLabel(for: interval)).tag(interval)
                    }
                }
                .onChange(of: bluetoothReconnectInterval) { _, newValue in
                    DeviceAutomationStore.saveBluetoothReconnectInterval(newValue)
                    BluetoothReconnectManager.shared.updatePollInterval()
                }

                Text("Shorter intervals connect faster but use more battery. 8 seconds is a good default.")
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
        .onAppear {
            if !DeviceAutomationStore.bluetoothReconnectIntervalOptions.contains(bluetoothReconnectInterval) {
                bluetoothReconnectInterval = DeviceAutomationStore.defaultBluetoothReconnectInterval
            }
        }
    }

    private func intervalLabel(for interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if interval == DeviceAutomationStore.defaultBluetoothReconnectInterval {
            return "\(seconds) seconds (default)"
        }
        return "\(seconds) seconds"
    }
}

#Preview {
    SettingsView()
}
