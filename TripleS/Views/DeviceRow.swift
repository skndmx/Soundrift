import SwiftUI

struct DeviceRow: View {
    @StateObject private var audioManager = AudioManager.shared
    let device: AudioDevice
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: audioManager.selectedDevices.contains(device) ? "checkmark.square.fill" : "square")
                .foregroundColor(audioManager.selectedDevices.contains(device) ? Color.cyan : Color.gray)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .fontWeight(.medium)
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.id == audioManager.currentDevice?.id {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if audioManager.selectedDevices.contains(device) {
                audioManager.selectedDevices.remove(device)
            } else {
                audioManager.selectedDevices.insert(device)
            }
            audioManager.saveSelectedDevices()
        }
        .padding(.horizontal)
    }
}

// Add this extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    if let previewDevice = AudioDevice(deviceID: 1) {
        DeviceRow(device: previewDevice)
            .environmentObject(AudioManager.shared)
    }
} 