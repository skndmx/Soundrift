import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    var id: AudioDeviceID
    var name: String
    var isOutput: Bool
    var isAirPlay: Bool
    var isInput: Bool
    
    static func getAllDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                     &address,
                                     0,
                                     nil,
                                     &propertySize)
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                 &address,
                                 0,
                                 nil,
                                 &propertySize,
                                 &deviceIDs)
        
        for deviceID in deviceIDs {
            if let device = AudioDevice(deviceID: deviceID) {
                if device.isOutput {
                    devices.append(device)
                }
            }
        }
        
        return devices
    }
    
    init?(deviceID: AudioDeviceID) {
        self.id = deviceID
        
        // Initialize properties with default values
        self.isOutput = false
        self.isAirPlay = false
        self.isInput = false
        self.name = ""
        
        // Get device name
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var cfName: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        
        let result = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &propertySize,
            &cfName
        )
        
        guard result == noErr,
              let unmanagedName = cfName else {
            return nil
        }
        
        self.name = unmanagedName.takeRetainedValue() as String
        
        // Check specifically for output streams
        address.mSelector = kAudioDevicePropertyStreamConfiguration
        address.mScope = kAudioDevicePropertyScopeOutput
        
        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propSize) == noErr,
              let audioBufferList = malloc(Int(propSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
            return
        }
        defer { free(audioBufferList) }
        
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propSize, audioBufferList) == noErr else {
            return
        }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let outputChannelCount = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
        
        // Determine if the device is an AirPlay device
        self.isAirPlay = isAirPlayDevice(deviceID: deviceID)
        
        // Determine if the device is an input device
        address.mScope = kAudioDevicePropertyScopeInput
        var inputPropSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &inputPropSize) == noErr else {
            return
        }
        self.isInput = inputPropSize > 0;
        
        // Consider the device as output if it has output channels or is an AirPlay device
        self.isOutput = outputChannelCount > 0 || self.isAirPlay
    }
    
    private func isAirPlayDevice(deviceID: AudioDeviceID) -> Bool {
        // Check for transport type
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        
        let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        
        // Check if it's an AirPlay device by transport type
        if result == noErr {
            return transportType == kAudioDeviceTransportTypeAirPlay ||
                   transportType == kAudioDeviceTransportTypeVirtual
        }
        
        return false
    }
    
    var isConnected: Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var isAlive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let deviceID = self.id
        
        let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isAlive)
        return result == noErr && isAlive == 1
    }
    
    func setAsDefault() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceIDCopy = self.id  // Create a mutable copy
        
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDCopy
        ) == noErr
    }
    
    static func getCurrentDefault() -> AudioDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        return result == noErr ? AudioDevice(deviceID: deviceID) : nil
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.id == rhs.id
    }
    
    var hasOutputChannels: Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &propSize) == noErr,
              let audioBufferList = malloc(Int(propSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
            return false
        }
        defer { free(audioBufferList) }
        
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &propSize, audioBufferList) == noErr else {
            return false
        }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let outputChannelCount = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
        
        return outputChannelCount > 0
    }
    
    #if DEBUG
    init(previewWithName name: String) {
        self.id = 0
        self.name = name
        self.isOutput = true
        self.isAirPlay = false // Set to false for preview
        self.isInput = false // Set to false for preview
    }
    #endif
} 