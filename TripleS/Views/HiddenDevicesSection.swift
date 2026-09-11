import SwiftUI

struct HiddenDevicesSection: View {
    let devices: [AudioDevice]
    let onShow: (AudioDevice) -> Void

    @State private var isExpanded = true

    var body: some View {
        if !devices.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 6) {
                    ForEach(devices) { device in
                        HiddenDeviceRow(device: device) {
                            onShow(device)
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Label {
                    Text("Hidden (\(devices.count))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.secondary)
        }
    }
}

struct HiddenDeviceRow: View {
    let device: AudioDevice
    let onShow: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(device.name)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(device.isConnected ? "Connected" : "Disconnected")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button("Unhide", action: onShow)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .frame(height: SoundriftTheme.rowHeight)
        .background(SoundriftTheme.rowFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(0.9)
    }
}
