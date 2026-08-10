import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    var id: AudioDeviceID
    var name: String
    var isOutput: Bool
    var isAirPlay: Bool
    var isInput: Bool
    var isBluetooth: Bool
    
    var isMicrosoftTeamsAudio: Bool {
        name.localizedCaseInsensitiveContains("Microsoft Teams")
    }
    
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
                if device.isInput || device.isOutput {
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
        self.isBluetooth = false
        self.name = ""
        
        guard populate(from: deviceID) else {
            return nil
        }
    }

    init(saved: SavedDevice) {
        self.id = saved.id
        self.name = saved.name
        self.isOutput = saved.isOutput
        self.isInput = saved.isInput
        self.isAirPlay = saved.isAirPlay
        self.isBluetooth = saved.isBluetooth
    }

    private mutating func populate(from deviceID: AudioDeviceID) -> Bool {
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
            return false
        }
        
        self.name = unmanagedName.takeRetainedValue() as String
        
        // Check specifically for output streams
        address.mSelector = kAudioDevicePropertyStreamConfiguration
        address.mScope = kAudioDevicePropertyScopeOutput
        
        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propSize) == noErr,
              let audioBufferList = malloc(Int(propSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
            return false
        }
        defer { free(audioBufferList) }
        
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propSize, audioBufferList) == noErr else {
            return false
        }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let outputChannelCount = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }

        let transportType = Self.transportType(for: deviceID)
        self.isAirPlay = Self.isAirPlayTransport(transportType)
        self.isBluetooth = Self.isBluetoothTransport(transportType)
        
        // Determine if the device is an input device
        address.mSelector = kAudioDevicePropertyStreamConfiguration
        address.mScope = kAudioDevicePropertyScopeInput
        
        var inputPropSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &inputPropSize) == noErr,
              let inputAudioBufferList = malloc(Int(inputPropSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
            return false
        }
        defer { free(inputAudioBufferList) }
        
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &inputPropSize, inputAudioBufferList) == noErr else {
            return false
        }
        
        let inputBufferList = UnsafeMutableAudioBufferListPointer(inputAudioBufferList)
        let inputChannelCount = inputBufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
        
        self.isInput = inputChannelCount > 0
        
        // Consider the device as output if it has output channels or is an AirPlay device
        self.isOutput = outputChannelCount > 0 || self.isAirPlay
        return true
    }
    
    private static func transportType(for deviceID: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType) == noErr else {
            return nil
        }

        return transportType
    }

    private static func isAirPlayTransport(_ transportType: UInt32?) -> Bool {
        guard let transportType else { return false }
        return transportType == kAudioDeviceTransportTypeAirPlay
            || transportType == kAudioDeviceTransportTypeVirtual
    }

    private static func isBluetoothTransport(_ transportType: UInt32?) -> Bool {
        guard let transportType else { return false }
        if transportType == kAudioDeviceTransportTypeBluetooth {
            return true
        }
        if transportType == kAudioDeviceTransportTypeBluetoothLE {
            return true
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
        self.isAirPlay = false
        self.isInput = false
        self.isBluetooth = false
    }
    #endif
    
    func setAsDefaultInput() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceIDCopy = self.id
        
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDCopy
        ) == noErr
    }
    
    static func getCurrentDefaultInput() -> AudioDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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
} 