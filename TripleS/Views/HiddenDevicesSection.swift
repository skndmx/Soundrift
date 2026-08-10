import SwiftUI

struct HiddenDevicesSection: View {
    let devices: [AudioDevice]
    let onShow: (AudioDevice) -> Void

    @State private var isExpanded = true

    var body: some View {
        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(spacing: 8) {
                        ForEach(devices) { device in
                            HiddenDeviceRow(device: device) {
                                onShow(device)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label {
                        Text("Hidden (\(devices.count))")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Hidden devices won't appear above or in your shortcut rotation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

struct HiddenDeviceRow: View {
    let device: AudioDevice
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Unhide", action: onShow)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .opacity(0.85)
    }
}
