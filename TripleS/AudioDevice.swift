import CoreAudio

struct AudioDevice: Identifiable, Hashable {
    var id: AudioDeviceID
    var name: String
    var uid: String
    var isOutput: Bool
    var isAirPlay: Bool
    var isBluetooth: Bool
    var bluetoothProductID: UInt16
    var airPlayDataSourceID: UInt32
    var isInput: Bool
    
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
        self.isBluetooth = false
        self.bluetoothProductID = 0
        self.airPlayDataSourceID = 0
        self.isInput = false
        self.name = ""
        self.uid = ""
        self.isConnected = false
        
        guard populate(from: deviceID) else {
            return nil
        }
        resolveBluetoothIdentityIfNeeded()
        self.isConnected = Self.isAvailableAsConnectedDevice(
            deviceID,
            isOutput: isOutput,
            isInput: isInput
        )
    }

    init(saved: SavedDevice) {
        self.id = saved.id
        self.name = saved.name
        self.uid = ""
        self.isOutput = saved.isOutput
        self.isInput = saved.isInput
        self.isAirPlay = saved.isAirPlay && !saved.name.localizedCaseInsensitiveContains("Microsoft Teams")
        self.isBluetooth = saved.isBluetooth
        self.bluetoothProductID = saved.bluetoothProductID
        self.airPlayDataSourceID = 0
        // Offline / remembered devices must not query Core Audio with stale IDs
        // (that spams "no object with given ID" in the console).
        self.isConnected = false
        resolveBluetoothIdentityIfNeeded()
    }

    /// Product ID is not on the HAL device; it comes from the paired Bluetooth
    /// record, matched by name (so a renamed 🐼 still maps to AirPods Pro).
    private mutating func resolveBluetoothIdentityIfNeeded() {
        guard bluetoothProductID == 0 else { return }
        guard let productID = BluetoothAudioIdentity.productID(matchingName: name), productID != 0 else {
            return
        }
        bluetoothProductID = productID
        isBluetooth = true
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

        address.mSelector = kAudioDevicePropertyDeviceUID
        var cfUID: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &uidSize, &cfUID) == noErr,
           let unmanagedUID = cfUID {
            self.uid = unmanagedUID.takeRetainedValue() as String
        } else {
            self.uid = ""
        }        
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

        let transport = Self.transportType(for: deviceID)
        self.isAirPlay = Self.isAirPlayTransport(transport)
        self.isBluetooth = Self.isBluetoothTransport(transport)
        if isAirPlay {
            let source = AirPlayEndpoint.currentOutputSource(for: deviceID)
            if let source {
                self.airPlayDataSourceID = source.id
            }
            self.name = AirPlayReceiverDirectory.shared.resolvedDisplayName(
                halName: name,
                uid: uid,
                dataSourceName: source?.name
            )
        }
        
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
        transportType == kAudioDeviceTransportTypeAirPlay
    }

    /// Continuity Camera / iPhone mic.
    var isContinuityCapture: Bool {
        guard let transportType = Self.transportType(for: id) else { return false }
        return transportType == kAudioDeviceTransportTypeContinuityCaptureWired
            || transportType == kAudioDeviceTransportTypeContinuityCaptureWireless
    }

    /// Whether macOS allows this device to become the system default for the given scope.
    func canBeSystemDefault(scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &address) else { return true }

        var can: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &can) == noErr else {
            return false
        }
        return can != 0
    }

    /// Alive is not enough for AirPods-in-case: HAL often keeps the device listed
    /// with IsAlive=1 after audio has already fallen back to speakers.
    private static func isAvailableAsConnectedDevice(
        _ deviceID: AudioDeviceID,
        isOutput: Bool,
        isInput: Bool
    ) -> Bool {
        let transport = transportType(for: deviceID)
        let isAirPlay = isAirPlayTransport(transport)
        return AudioDeviceAvailability.isConnected(
            isAlive: isAlive(deviceID),
            isBluetooth: isBluetoothTransport(transport),
            jackUnplugged: isAirPlay ? false : isJackUnplugged(deviceID),
            canBeDefaultOutput: readCanBeDefault(deviceID, scope: kAudioDevicePropertyScopeOutput),
            canBeDefaultInput: readCanBeDefault(deviceID, scope: kAudioDevicePropertyScopeInput),
            isOutput: isOutput,
            isInput: isInput
        )
    }

    private static func readCanBeDefault(
        _ deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var can: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &can) == noErr else {
            return false
        }
        return can != 0
    }

    private static func isJackUnplugged(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyJackIsConnected,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if !AudioObjectHasProperty(deviceID, &address) {
            address.mScope = kAudioDevicePropertyScopeOutput
            guard AudioObjectHasProperty(deviceID, &address) else { return false }
        }

        var connected: UInt32 = 1
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &connected) == noErr else {
            return false
        }
        return connected == 0
    }

    private static func isBluetoothTransport(_ transportType: UInt32?) -> Bool {
        guard let transportType else { return false }
        return transportType == kAudioDeviceTransportTypeBluetooth
            || transportType == kAudioDeviceTransportTypeBluetoothLE
    }

    /// Snapshot from the last enumeration / merge. Do not query Core Audio here —
    /// stale IDs from remembered devices spam `no object with given ID` logs.
    var isConnected: Bool

    private static func isAlive(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var isAlive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isAlive)
        return result == noErr && isAlive == 1
    }
    
    var isBluetoothTransport: Bool { isBluetooth }

    func channelCount(scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &propSize) == noErr,
              let audioBufferList = malloc(Int(propSize))?.assumingMemoryBound(to: AudioBufferList.self) else {
            return 0
        }
        defer { free(audioBufferList) }

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &propSize, audioBufferList) == noErr else {
            return 0
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    func nominalSampleRate() -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &rate) == noErr else {
            return 0
        }
        return rate
    }

    func setAsDefault() -> Bool {
        if isAirPlay, airPlayDataSourceID != 0 {
            _ = AirPlayEndpoint.setCurrentOutputSource(airPlayDataSourceID, on: id)
        }
        let defaultOK = setHardwareDefault(kAudioHardwarePropertyDefaultOutputDevice)
        // Alert sounds live on a separate default. Best-effort so virtual devices
        // that reject system-output still switch app audio.
        _ = setHardwareDefault(kAudioHardwarePropertyDefaultSystemOutputDevice)
        return defaultOK
    }

    func setHardwareDefault(_ selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceIDCopy = id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceIDCopy
        )
        if status != noErr {
            print("HAL set selector=\(selector) failed status=\(status) device=\(name) id=\(id)")
        }
        return status == noErr
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
        channelCount(scope: kAudioDevicePropertyScopeOutput) > 0
    }

    /// SF Symbol matching Control Center's sound output/input glyphs.
    func glyphSystemName(kind: DeviceType) -> String {
        NativeAudioDeviceIcon.systemImageName(for: self, kind: kind)
    }
    
    #if DEBUG
    init(previewWithName name: String) {
        self.id = 0
        self.name = name
        self.uid = ""
        self.isOutput = true
        self.isAirPlay = false
        self.isBluetooth = false
        self.bluetoothProductID = 0
        self.airPlayDataSourceID = 0
        self.isInput = false
        self.isConnected = true
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