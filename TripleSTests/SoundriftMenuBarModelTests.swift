import Testing
@testable import Soundrift

struct SoundriftMenuBarModelTests {
    @Test func connectedDevicesSortBeforeDisconnected() {
        var hdmi = AudioDevice(previewWithName: "XG2431")
        hdmi.isConnected = false
        let speakers = AudioDevice(previewWithName: "MacBook Pro Speakers")
        var headphones = AudioDevice(previewWithName: "External Headphones")
        headphones.isConnected = false

        let sorted = SoundriftMenuBarModel.connectedFirst([hdmi, speakers, headphones])
        #expect(sorted.map(\.name) == [
            "MacBook Pro Speakers",
            "External Headphones",
            "XG2431"
        ])
    }

    @Test func currentDeviceIsCheckedAndDisconnectedRowsAreDisabled() {
        let speakers = AudioDevice(previewWithName: "MacBook Pro Speakers")
        var headphones = AudioDevice(previewWithName: "External Headphones")
        headphones.isConnected = false

        let rows = SoundriftMenuBarModel.deviceRows(
            devices: [headphones, speakers],
            current: speakers,
            kind: .output,
            isEnabled: { $0.isConnected }
        )

        #expect(rows.count == 2)
        #expect(rows[0].title == "MacBook Pro Speakers")
        #expect(rows[0].isCurrent)
        #expect(rows[0].isEnabled)
        #expect(rows[1].title == "External Headphones")
        #expect(!rows[1].isCurrent)
        #expect(!rows[1].isEnabled)
    }

    @Test func airPlayCurrentMatchUsesReceiverName() {
        var livingRoom = AudioDevice(previewWithName: "客厅")
        livingRoom.isAirPlay = true
        livingRoom.uid = "AirPlay-UID"

        var bedroom = AudioDevice(previewWithName: "Bedroom")
        bedroom.isAirPlay = true
        bedroom.uid = "AirPlay-UID"

        let rows = SoundriftMenuBarModel.deviceRows(
            devices: [livingRoom, bedroom],
            current: livingRoom,
            kind: .output,
            isEnabled: { _ in true }
        )

        #expect(rows.first { $0.title == "客厅" }?.isCurrent == true)
        #expect(rows.first { $0.title == "Bedroom" }?.isCurrent == false)
    }

    @Test func rememberedDevicesAreNotSwitchable() {
        let saved = SavedDevice(from: AudioDevice(previewWithName: "External Headphones"))
        let remembered = AudioDevice(saved: saved)
        #expect(!SoundriftMenuBarModel.isDeviceSwitchable(remembered, kind: .output))
    }
}
