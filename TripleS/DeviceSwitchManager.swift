import Foundation
import UserNotifications

class DeviceSwitchManager {
    static let shared = DeviceSwitchManager()
    private let audioManager = AudioManager.shared
    
    func switchToNextDevice(type: DeviceType) {
        switch type {
        case .output:
            audioManager.switchToNextDevice()
        case .input:
            switchToNextInputDevice()
        }
    }
    
    private func switchToNextInputDevice() {
        // Get connected input devices and ensure they're sorted
        let connectedDevices = audioManager.selectedInputDevices
            .filter { $0.isConnected }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        guard !connectedDevices.isEmpty else {
            print("Error: No connected input devices available")
            return
        }
        
        let currentIndex = connectedDevices.firstIndex { $0.id == audioManager.currentInputDevice?.id } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]
        
        if nextDevice.setAsDefaultInput() {
            audioManager.currentInputDevice = nextDevice
            NotificationCenter.default.post(name: NSNotification.Name("AudioInputDeviceSwitched"), object: nextDevice)
            
            // Show notification
            let content = UNMutableNotificationContent()
            content.title = "Audio Input Changed"
            content.body = "Switched to \(nextDevice.name)"
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error showing notification: \(error)")
                }
            }
        }
    }
} 