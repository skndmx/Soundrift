import SwiftUI

struct DevicesView: View {
    @StateObject private var audioManager = AudioManager.shared
    @Binding var kind: DeviceType

    private var visibleDevices: [AudioDevice] {
        switch kind {
        case .output:
            audioManager.visibleOutputDevices
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .input:
            audioManager.visibleInputDevices
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
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
                    ActiveDeviceHero(device: currentDevice, kind: kind)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("In rotation")
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
