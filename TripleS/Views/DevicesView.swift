import SwiftUI

struct DevicesView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var pane: DeviceType = .output

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Device kind", selection: $pane) {
                ForEach(DeviceType.allCases, id: \.self) { kind in
                    Text(kind.paneTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .labelsHidden()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let current = currentDevice {
                        ActiveDeviceHero(device: current, kind: pane)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("In rotation")
                            .font(.headline)
                        Text("Checked devices cycle with your shortcut")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 6) {
                            ForEach(visibleDevices) { device in
                                AudioDeviceRow(device: device, kind: pane)
                            }
                        }
                    }

                    HiddenDevicesSection(devices: hiddenDevices) { device in
                        showDevice(device)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var currentDevice: AudioDevice? {
        switch pane {
        case .output: audioManager.currentDevice
        case .input: audioManager.currentInputDevice
        }
    }

    private var visibleDevices: [AudioDevice] {
        let devices: [AudioDevice]
        switch pane {
        case .output: devices = audioManager.visibleOutputDevices
        case .input: devices = audioManager.visibleInputDevices
        }
        return devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var hiddenDevices: [AudioDevice] {
        let devices: [AudioDevice]
        switch pane {
        case .output: devices = audioManager.hiddenOutputDevices
        case .input: devices = audioManager.hiddenInputDevices
        }
        return devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func showDevice(_ device: AudioDevice) {
        switch pane {
        case .output: audioManager.showOutputDevice(device)
        case .input: audioManager.showInputDevice(device)
        }
    }
}
