import SwiftUI

struct HiddenDevicesSection: View {
    let devices: [AudioDevice]
    let onShow: (AudioDevice) -> Void

    @State private var isExpanded = false

    var body: some View {
        if !devices.isEmpty {
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
                Text("Hidden devices (\(devices.count))")
                    .font(.headline)
            }
            .padding(.horizontal)
        }
    }
}

struct HiddenDeviceRow: View {
    let device: AudioDevice
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Show", action: onShow)
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .opacity(0.7)
    }
}
