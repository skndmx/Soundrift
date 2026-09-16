import SwiftUI

struct DevicesView: View {
    @StateObject private var audioManager = AudioManager.shared
    @ObservedObject var hotkeys: HotkeyController
    @Binding var kind: DeviceType

    private var visibleDevices: [AudioDevice] {
        let devices: [AudioDevice] = switch kind {
        case .output: audioManager.visibleOutputDevices
        case .input: audioManager.visibleInputDevices
        }
        return Self.connectedFirst(devices)
    }

    private var hiddenDevices: [AudioDevice] {
        switch kind {
        case .output:
            audioManager.hiddenOutputDevices
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .input:
            audioManager.hiddenInputDevices
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private var currentDevice: AudioDevice? {
        switch kind {
        case .output: audioManager.currentDevice
        case .input: audioManager.currentInputDevice
        }
    }

    private var cycleKeycaps: [String] {
        switch kind {
        case .output: hotkeys.outputKeycaps
        case .input: hotkeys.inputKeycaps
        }
    }

    private static func connectedFirst(_ devices: [AudioDevice]) -> [AudioDevice] {
        devices.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected && !rhs.isConnected
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                Picker("Device kind", selection: $kind) {
                    Text("Output").tag(DeviceType.output)
                    Text("Input").tag(DeviceType.input)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)

                if let currentDevice {
                    ActiveDeviceHero(device: currentDevice, kind: kind, cycleKeycaps: cycleKeycaps)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Devices")
                        .font(.headline)

                    Text("Checked devices cycle with your shortcut. Adjust volume or mute before switching.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !visibleDevices.isEmpty {
                        GroupedDeviceList {
                            ForEach(Array(visibleDevices.enumerated()), id: \.element.endpointID) { index, device in
                                AudioDeviceRow(device: device, kind: kind)
                                if index < visibleDevices.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                }

                HiddenDevicesSection(devices: hiddenDevices) { device in
                    switch kind {
                    case .output: audioManager.showOutputDevice(device)
                    case .input: audioManager.showInputDevice(device)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            }
        }
    }
}

struct GroupedDeviceList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .soundriftGlassCard()
    }
}
