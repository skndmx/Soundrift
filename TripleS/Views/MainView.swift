import SwiftUI

enum MainWindowTab: String, CaseIterable, Identifiable {
    case devices
    case shortcuts
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: "Devices"
        case .shortcuts: "Shortcuts"
        case .settings: "Settings"
        }
    }
}

struct MainView: View {
    @StateObject private var hotkeys = HotkeyController()
    @State private var tab: MainWindowTab = .devices
    @State private var deviceKind: DeviceType = .output

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Group {
                switch tab {
                case .devices:
                    DevicesView(kind: $deviceKind)
                case .shortcuts:
                    ShortcutsView(hotkeys: hotkeys)
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(.clear)
        .tint(SoundriftTheme.accent)
        .frame(minWidth: 560, minHeight: 440)
        .onAppear {
            hotkeys.registerAll()
        }
    }

    /// Brand + tabs sit below the real titlebar. That strip still looks like
    /// the same glass, but it is the only region that moves the window.
    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SoundriftHeaderIcon(pointSize: 44)
                Text("Soundrift")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Soundrift")
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Picker("Section", selection: $tab) {
                ForEach(MainWindowTab.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .labelsHidden()
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Downsamples the 1024 AppIcon2 asset at the window's backing scale so the
/// header stays sharp on Retina. SwiftUI `Image.resizable()` otherwise
/// rasterizes a 1× 44 px bitmap and the display stretches it.
private struct SoundriftHeaderIcon: View {
    var pointSize: CGFloat = 44
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: Self.rasterized(pointSize: pointSize, scale: displayScale))
            .frame(width: pointSize, height: pointSize)
    }

    private static func rasterized(pointSize: CGFloat, scale: CGFloat) -> NSImage {
        let pixels = max(1, Int((pointSize * max(scale, 1)).rounded()))
        let size = NSSize(width: pointSize, height: pointSize)
        guard let source = NSImage(named: "AppIcon2"),
              let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: [
                  .interpolation: NSImageInterpolation.high,
              ])
        else {
            return NSImage(size: size)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return source
        }

        context.interpolationQuality = .high
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.draw(cgSource, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))

        guard let output = context.makeImage() else { return source }
        return NSImage(cgImage: output, size: size)
    }
}

#Preview {
    MainView()
        .frame(width: SoundriftTheme.windowWidth, height: SoundriftTheme.windowHeight)
}
