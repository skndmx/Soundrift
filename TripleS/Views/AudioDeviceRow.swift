import SwiftUI

struct AudioDeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    let kind: DeviceType

    private var isSelected: Bool {
        switch kind {
        case .output: audioManager.isOutputDeviceSelected(device)
        case .input: audioManager.isInputDeviceSelected(device)
        }
    }

    private var isCurrentDevice: Bool {
        switch kind {
        case .output:
            device.id == audioManager.currentDevice?.id || device.name == audioManager.currentDevice?.name
        case .input:
            device.id == audioManager.currentInputDevice?.id || device.name == audioManager.currentInputDevice?.name
        }
    }

    private var autoSwitchLabel: String {
        kind == .output ? "Auto-switch output when connected" : "Auto-switch input when connected"
    }

    private var hasAutomationEnabled: Bool {
        audioManager.isAutoSwitchOnConnectEnabled(device, kind: kind)
            || audioManager.isAutoReconnectBluetoothEnabled(device)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                guard device.isConnected else { return }
                setSelected(!isSelected)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? Color.cyan : .secondary)
                    .font(.system(size: 16))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(!device.isConnected)
            .help(device.isConnected ? "Include in shortcut rotation" : "Connect device to include in rotation")

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                    .foregroundStyle(device.isConnected ? .primary : .secondary)
                HStack(spacing: 8) {
                    Text(device.isConnected ? "Connected" : "Disconnected")
                    if audioManager.isAutoSwitchOnConnectEnabled(device, kind: kind) {
                        Label("Auto-switch", systemImage: "arrow.triangle.swap")
                            .labelStyle(.titleAndIcon)
                    }
                    if audioManager.isAutoReconnectBluetoothEnabled(device) {
                        Label("BT reconnect", systemImage: "antenna.radiowaves.left.and.right")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if device.isConnected, isCurrentDevice {
                    rowIcon(kind == .output ? "speaker.wave.3.fill" : "mic.fill")
                        .foregroundStyle(.blue)
                        .help("Currently active")
                } else {
                    Color.clear
                        .frame(width: 28, height: 28)
                }

                AutomationOptionsButton(
                    autoSwitchLabel: autoSwitchLabel,
                    autoSwitchBinding: autoSwitchBinding,
                    autoReconnectBinding: autoReconnectBinding,
                    isActive: hasAutomationEnabled
                )

                Button(action: hideDevice) {
                    rowIcon("eye.slash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide this device from the list")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .opacity(device.isConnected ? 1 : 0.55)
        .padding(.horizontal)
    }

    private var autoSwitchBinding: Binding<Bool> {
        Binding(
            get: { audioManager.isAutoSwitchOnConnectEnabled(device, kind: kind) },
            set: { audioManager.setAutoSwitchOnConnect(device, kind: kind, enabled: $0) }
        )
    }

    private var autoReconnectBinding: Binding<Bool> {
        Binding(
            get: { audioManager.isAutoReconnectBluetoothEnabled(device) },
            set: { audioManager.setAutoReconnectBluetooth(device, enabled: $0) }
        )
    }

    private func setSelected(_ selected: Bool) {
        switch kind {
        case .output: audioManager.setOutputDeviceSelected(device, selected: selected)
        case .input: audioManager.setInputDeviceSelected(device, selected: selected)
        }
    }

    private func hideDevice() {
        switch kind {
        case .output: audioManager.hideOutputDevice(device)
        case .input: audioManager.hideInputDevice(device)
        }
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .frame(width: 28, height: 28)
    }
}

private struct AutomationOptionsButton: View {
    let autoSwitchLabel: String
    let autoSwitchBinding: Binding<Bool>
    let autoReconnectBinding: Binding<Bool>
    let isActive: Bool

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "bolt.circle")
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .foregroundStyle(isActive ? .cyan : .secondary)
        }
        .buttonStyle(.plain)
        .help("Connection automation")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("When this device connects")
                    .font(.headline)

                Toggle(autoSwitchLabel, isOn: autoSwitchBinding)
                Toggle("Auto-reconnect Bluetooth", isOn: autoReconnectBinding)
            }
            .padding(16)
            .frame(width: 280)
        }
    }
}

struct DeviceListHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text("Check devices for your shortcut. Use the bolt icon for auto-switch or Bluetooth reconnect.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
