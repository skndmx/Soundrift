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
            audioManager.switchToNextInputDevice()
        }
    }
}
