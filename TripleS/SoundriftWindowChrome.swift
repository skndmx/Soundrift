import AppKit
import SwiftUI

enum SoundriftWindowChrome {
    /// One continuous glass surface: traffic lights sit on the content,
    /// with no separate titlebar material or separator (Image Playground–style).
    /// Only the real titlebar strip moves the window; SwiftUI is laid out below it.
    static func applyLiquidGlass(to window: NSWindow, hostingView: NSView) {
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.toolbar = nil
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = false

        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let glass = NSGlassEffectView()
        glass.style = .regular
        // Window chrome already rounds the outer corners. A radius here would
        // draw a second curve inset from the window edge.
        glass.cornerRadius = 0

        let passthrough = TitlebarPassthroughView()
        passthrough.wantsLayer = true
        passthrough.layer?.backgroundColor = NSColor.clear.cgColor
        glass.contentView = passthrough
        window.contentView = glass

        passthrough.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        let guide = window.contentLayoutGuide as! NSLayoutGuide
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: passthrough.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: passthrough.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: passthrough.bottomAnchor),
            hostingView.topAnchor.constraint(equalTo: guide.topAnchor)
        ])
    }
}

/// Empty hits in the titlebar band fall through to the real titlebar so the
/// window can be dragged there without making the rest of the glass movable.
private final class TitlebarPassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}
