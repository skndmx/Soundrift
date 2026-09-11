import SwiftUI

enum SoundriftTheme {
    /// System Settings–like indigo accent (~#5E5CE6).
    static let accent = Color(red: 94 / 255, green: 92 / 255, blue: 230 / 255)
    static let activeGreen = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let recordingRed = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)

    static let rowHeight: CGFloat = 40
    static let groupedCornerRadius: CGFloat = 8
    static let contentWidth: CGFloat = 640
    static let windowWidth: CGFloat = 680
    static let windowHeight: CGFloat = 540

    static var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let parts = short.split(separator: ".")
        if parts.count >= 3 {
            return short
        }
        return "\(short).\(build)"
    }
}
