import Foundation
import CoreAudio

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevices: Set<AudioDevice> = []
    @Published var currentDevice: AudioDevice?
    
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    
    private let selectedDevicesKey = "SelectedDevices"
    
    private init() {
        // Load saved selected devices
        if let savedDeviceIDs = UserDefaults.standard.array(forKey: selectedDevicesKey) as? [AudioDeviceID] {
            DispatchQueue.main.async { [weak self] in
                self?.availableDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
                self?.selectedDevices = Set(self?.availableDevices.filter { savedDeviceIDs.contains($0.id) } ?? [])
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
        availableDevices = AudioDevice.getAllDevices().filter { $0.isOutput }
        currentDevice = AudioDevice.getCurrentDefault()
    }
    
    func switchToNextDevice() {
        print("=== Device Switch Attempt ===")
        print("Selected devices count: \(selectedDevices.count)")
        selectedDevices.forEach { device in
            print("Selected device: \(device.name) (connected: \(device.isConnected))")
        }
        
        let connectedDevices = Array(selectedDevices).filter { $0.isConnected }
        print("Connected devices count: \(connectedDevices.count)")
        
        guard !connectedDevices.isEmpty else {
            print("Error: No connected devices available")
            return
        }
        
        let currentIndex = connectedDevices.firstIndex { $0.id == currentDevice?.id } ?? -1
        print("Current device index: \(currentIndex)")
        
        let nextIndex = (currentIndex + 1) % connectedDevices.count
        let nextDevice = connectedDevices[nextIndex]
        print("Attempting to switch to: \(nextDevice.name)")
        
        if nextDevice.setAsDefault() {
            print("Successfully switched to: \(nextDevice.name)")
            currentDevice = nextDevice
            NotificationCenter.default.post(name: NSNotification.Name("AudioDeviceSwitched"), object: nextDevice)
        } else {
            print("Failed to switch to: \(nextDevice.name)")
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