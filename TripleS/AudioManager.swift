import Foundation
import CoreAudio
import UserNotifications

struct SavedDevice: Codable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevices: Set<AudioDevice> = []
    @Published var currentDevice: AudioDevice?
    @Published var selectedInputDevices: Set<AudioDevice> = []
    @Published var currentInputDevice: AudioDevice?
    @Published var availableInputDevices: [AudioDevice] = []
    
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    
    private let selectedDevicesKey = "SelectedDevices"
    private let selectedInputDevicesKey = "SelectedInputDevices"
    
    private init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
        
        // Initialize and load saved devices synchronously to avoid race conditions
        let outputDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let inputDevices = AudioDevice.getAllDevices().filter { $0.isInput }
        
        // Initialize output devices
        self.availableDevices = outputDevices
        self.selectedDevices = loadSavedDevices(from: selectedDevicesKey, devices: outputDevices)
        self.currentDevice = AudioDevice.getCurrentDefault()
        
        // Initialize input devices
        self.availableInputDevices = inputDevices
        self.selectedInputDevices = loadSavedDevices(from: selectedInputDevicesKey, devices: inputDevices)
        self.currentInputDevice = AudioDevice.getCurrentDefaultInput()
        
        // Save initial states if needed
        if UserDefaults.standard.array(forKey: selectedDevicesKey) == nil {
            saveSelectedDevices()
        }
        if UserDefaults.standard.array(forKey: selectedInputDevicesKey) == nil {
            saveSelectedInputDevices()
        }
        
        // Setup listeners after initialization
        setupDeviceListener()
        setupDefaultDeviceListener()
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
                self?.refreshInputDevices()
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
        // Output device monitoring
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Input device monitoring
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        defaultDeviceListener = { [weak self] (
            _ inNumberAddresses: UInt32,
            _ inPropertyAddresses: UnsafePointer<AudioObjectPropertyAddress>
        ) in
            DispatchQueue.main.async {
                self?.currentDevice = AudioDevice.getCurrentDefault()
                self?.currentInputDevice = AudioDevice.getCurrentDefaultInput()
            }
        }
        
        guard let listener = defaultDeviceListener else { return }
        
        // Add listener for output device changes
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            nil,
            listener
        )
        
        // Add listener for input device changes
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &inputAddress,
            nil,
            listener
        )
    }
    
    func refreshAudioDevices() {
        let unsortedDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        let sortedDevices = unsortedDevices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        // Keep track of previously selected device IDs
        let selectedDeviceIDs = Set(selectedDevices.map { $0.id })
        
        availableDevices = sortedDevices
        
        // Maintain selection state for existing devices
        selectedDevices = Set(sortedDevices.filter { device in 
            selectedDeviceIDs.contains(device.id)
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
    func saveSelectedDevices() {
        let savedDevices = selectedDevices.map { device in
            SavedDevice(id: device.id, name: device.name, isInput: false)
        }
        if let encoded = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(encoded, forKey: selectedDevicesKey)
        }
    }
    
    func refreshInputDevices() {
        let unsortedDevices = AudioDevice.getAllDevices().filter { $0.isInput }
        let sortedDevices = unsortedDevices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        
        // Keep track of previously selected device IDs
        let selectedDeviceIDs = Set(selectedInputDevices.map { $0.id })
        
        availableInputDevices = sortedDevices
        
        // Maintain selection state for existing devices
        selectedInputDevices = Set(sortedDevices.filter { device in 
            selectedDeviceIDs.contains(device.id)
        })
        
        saveSelectedInputDevices()
        currentInputDevice = AudioDevice.getCurrentDefaultInput()
    }
    
    func saveSelectedInputDevices() {
        let savedDevices = selectedInputDevices.map { device in
            SavedDevice(id: device.id, name: device.name, isInput: true)
        }
        if let encoded = try? JSONEncoder().encode(savedDevices) {
            UserDefaults.standard.set(encoded, forKey: selectedInputDevicesKey)
        }
    }
    
    private func loadSavedDevices(from key: String, devices: [AudioDevice]) -> Set<AudioDevice> {
        if let data = UserDefaults.standard.data(forKey: key),
           let savedDevices = try? JSONDecoder().decode([SavedDevice].self, from: data) {
            return Set(devices.filter { device in
                savedDevices.contains { saved in
                    saved.id == device.id || saved.name == device.name
                }
            })
        }
        return Set(devices)
    }
} 