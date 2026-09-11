import SwiftUI

struct ActiveDeviceHero: View {
    let device: AudioDevice
    let kind: DeviceType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.glyphSystemName(kind: kind))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(SoundriftTheme.accent, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                ActiveStatusPill()
            }

            Spacer(minLength: 12)

            DeviceVolumeSlider(device: device, kind: kind)
                .frame(maxWidth: 240)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SoundriftTheme.heroFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ActiveStatusPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.16), in: Capsule())
    }
}
