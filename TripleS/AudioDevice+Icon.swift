import Foundation
import IOBluetooth

enum NativeAudioDeviceIcon {
    static func systemImageName(for device: AudioDevice, kind: DeviceType) -> String {
        if let symbol = symbolName(forProductID: device.bluetoothProductID) {
            return symbol
        }
        return fallbackSystemImageName(for: device, kind: kind)
    }

    /// Apple accessory product IDs from the Bluetooth PnP record.
    static func symbolName(forProductID productID: UInt16) -> String? {
        switch productID {
        case 0x200A:
            return "airpods.max"
        case 0x200E, 0x2014, 0x2024:
            return "airpods.pro"
        case 0x2013:
            return "airpods.gen3"
        case 0x2027:
            return "airpods.gen4"
        case 0x2002, 0x200F:
            return "airpods"
        case 0x2011:
            return "beats.powerbeatspro"
        case 0x2019, 0x201D:
            return "beats.studiobuds"
        case 0x201C:
            return "beats.fitpro"
        case 0x200B, 0x200C, 0x2012:
            return "beats.headphones"
        default:
            return nil
        }
    }

    static func fallbackSystemImageName(for device: AudioDevice, kind: DeviceType) -> String {
        let n = device.name.lowercased()

        if n.contains("airpods max") { return "airpods.max" }
        if n.contains("airpods pro") { return "airpods.pro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("beats fit") { return "beats.fitpro" }
        if n.contains("studio buds") { return "beats.studiobuds" }
        if n.contains("powerbeats") { return "beats.powerbeatspro" }
        if n.contains("beats") { return "beats.headphones" }
        if n.contains("homepod mini") { return "homepod.mini.fill" }
        if n.contains("homepod") { return "homepod.fill" }
        if device.isMicrosoftTeamsAudio || n.contains("blackhole") || n.contains("loopback") || n.contains("aggregate") {
            return "cable.connector"
        }
        if device.isAirPlay || n.contains("airplay") || n.contains("apple tv") { return "appletv" }
        if n.contains("iphone") { return "iphone" }
        if n.contains("ipad") { return "ipad" }
        if n.contains("display") || n.contains("hdmi") || n.contains("monitor") { return "display" }
        if n.contains("usb") || n.contains("dac") {
            return "cable.connector"
        }

        if kind == .input {
            if n.contains("macbook") || n.contains("built-in") { return "mic.fill" }
            if device.isBluetooth || n.contains("headphone") || n.contains("headset") { return "headphones" }
            return "mic.fill"
        }

        if n.contains("macbook") || n.contains("built-in") { return "laptopcomputer" }
        if n.contains("headphone") || n.contains("headset") || device.isBluetooth { return "headphones" }
        return "hifispeaker.fill"
    }
}

enum BluetoothAudioIdentity {
    private static let lock = NSLock()
    private static var productIDsByName: [String: UInt16] = [:]
    private static var lastLoad = Date.distantPast

    static func productID(matchingName name: String) -> UInt16? {
        let key = AudioDeviceMatch.normalizedName(name).lowercased()
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if Date().timeIntervalSince(lastLoad) > 2 {
            reloadLocked()
        }
        return productIDsByName[key]
    }

    private static func reloadLocked() {
        lastLoad = Date()
        productIDsByName.removeAll(keepingCapacity: true)
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in devices {
            let name = device.name ?? device.nameOrAddress ?? ""
            guard !name.isEmpty else { continue }
            guard let record = device.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: 0x1200)),
                  let element = record.getAttributeDataElement(0x0202),
                  let number = element.getNumberValue() else { continue }
            let productID = number.uint16Value
            guard productID != 0 else { continue }
            productIDsByName[AudioDeviceMatch.normalizedName(name).lowercased()] = productID
        }
    }
}
