import SwiftUI

struct HiddenDevicesSection: View {
    let devices: [AudioDevice]
    let onShow: (AudioDevice) -> Void

    @State private var isExpanded = false

    var body: some View {
        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.snappy) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12, weight: .medium))
                        Text("Hidden (\(devices.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hidden devices, \(devices.count)")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isExpanded ? "Collapse" : "Expand")

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(Array(devices.enumerated()), id: \.element.endpointID) { index, device in
                            HiddenDeviceRow(device: device) {
                                onShow(device)
                            }
                            if index < devices.count - 1 {
                                Divider()
                                    .padding(.leading, 36)
                            }
                        }
                    }
                    .soundriftGlassCard()
                    .padding(.top, 6)
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
                .buttonStyle(.glass)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .frame(height: SoundriftTheme.rowHeight)
        .opacity(0.9)
    }
}
