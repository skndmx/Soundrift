import AppKit
import SwiftUI

struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = "Soundrift"
            window.isReleasedWhenClosed = false
            (NSApp.delegate as? AppDelegate)?.registerMainWindow(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
