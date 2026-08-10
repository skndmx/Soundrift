import AppKit
import SwiftUI

struct MainWindowAccessor: NSViewRepresentable {
    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }

    final class HookView: NSView {
        var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard let window, let coordinator, coordinator.configuredWindow !== window else { return }
            coordinator.configuredWindow = window

            window.title = "Soundrift"
            window.isReleasedWhenClosed = false
            (NSApp.delegate as? AppDelegate)?.registerMainWindow(window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> HookView {
        let view = HookView(frame: .zero)
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HookView, context: Context) {}
}
