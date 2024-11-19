import Foundation
import CoreAudio
import UserNotifications

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevices: Set<AudioDevice> = []
    @Published var currentDevice: AudioDevice?
    
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    
    private let selectedDevicesKey = "SelectedDevices"
    
    private init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Load saved selected devices
        if let savedDeviceIDs = UserDefaults.standard.array(forKey: selectedDevicesKey) as? [AudioDeviceID] {
            DispatchQueue.main.async { [weak self] in
                self?.availableDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
                self?.selectedDevices = Set(self?.availableDevices.filter { savedDeviceIDs.contains($0.id) } ?? [])
                self?.currentDevice = AudioDevice.getCurrentDefault()
            }
        } else {
            // Automatically select all available devices by default
            DispatchQueue.main.async { [weak self] in
                self?.availableDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
                self?.selectedDevices = Set(self?.availableDevices ?? [])
                self?.currentDevice = AudioDevice.getCurrentDefault()
            }
        }
        
        setupDeviceListener()
        setupDefaultDeviceListener()
        refreshAudioDevices()
    }
    
    private func setupDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        deviceListener = { [weak self] (
            _ inNumberAddresses: UInt32,
            _ inPropertyAddresses: UnsafePointer<AudioObjectPropertyAddress>
        ) in
            DispatchQueue.main.async {
                self?.refreshAudioDevices()
            }
        }
        
        guard let listener = deviceListener else { return }
        
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            listener
        )
    }
    
    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        defaultDeviceListener = { [weak self] (
            _ inNumberAddresses: UInt32,
            _ inPropertyAddresses: UnsafePointer<AudioObjectPropertyAddress>
        ) in
            DispatchQueue.main.async {
                self?.currentDevice = AudioDevice.getCurrentDefault()
            }
        }
        
        guard let listener = defaultDeviceListener else { return }
        
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            listener
        )
    }
    
    func refreshAudioDevices() {
        let unsortedDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let sortedDevices = unsortedDevices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        // Keep track of previously selected device IDs
        let selectedDeviceIDs = Set(selectedDevices.map { $0.id })
        
        // Keep track of previously known device IDs
        let previousDeviceIDs = Set(availableDevices.map { $0.id })
        
        availableDevices = sortedDevices
        
        // Find newly added devices
        let newDeviceIDs = Set(sortedDevices.map { $0.id }).subtracting(previousDeviceIDs)
        
        // Update selectedDevices to include both previously selected devices and new devices
        selectedDevices = Set(sortedDevices.filter { device in 
            selectedDeviceIDs.contains(device.id) || newDeviceIDs.contains(device.id)
        })
        
        saveSelectedDevices()
        currentDevice = AudioDevice.getCurrentDefault()
    }
    
    func switchToNextDevice() {
        // Get connected devices and ensure they're sorted
        let connectedDevices = selectedDevices
            .filter { $0.isConnected }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        guard !connectedDevices.isEmpty else {
            print("Error: No connected devices available")
            return
        }
        
        let currentIndex = connectedDevices.firstIndex { $0.id == currentDevice?.id } ?? -1
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]
        
        if nextDevice.setAsDefault() {
            currentDevice = nextDevice
            NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: nextDevice)
            
            // Show notification
            let content = UNMutableNotificationContent()
            content.title = "Audio Output Changed"
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
    
    deinit {
        if let listener = deviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
        }
        
        if let listener = defaultDeviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            _ = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                nil,
                listener
            )
        }
    }
    
    // Add this method to save selected devices
    private func saveSelectedDevices() {
        let deviceIDs = selectedDevices.map { $0.id }
        UserDefaults.standard.set(deviceIDs, forKey: selectedDevicesKey)
    }
} 