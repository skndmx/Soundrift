import SwiftUI

struct HiddenDevicesSection: View {
    let devices: [AudioDevice]
    let onShow: (AudioDevice) -> Void

    @State private var isExpanded = true

    var body: some View {
        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(spacing: 0) {
                        ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                            HiddenDeviceRow(device: device) {
                                onShow(device)
                            }
                            if index < devices.count - 1 {
                                Divider()
                                    .padding(.leading, 36)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: SoundriftTheme.groupedCornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: SoundriftTheme.groupedCornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }
                    .padding(.top, 6)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("Hidden (\(devices.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Hidden devices won't appear above or in your shortcut rotation.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18)

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
        .opacity(0.9)
    }
}
