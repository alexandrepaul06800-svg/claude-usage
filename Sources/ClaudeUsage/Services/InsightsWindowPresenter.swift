import AppKit
import SwiftUI

@MainActor
final class InsightsWindowPresenter {
    static let shared = InsightsWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func show(appState: AppState) {
        showWindow(
            title: L10n.tr("insights.window_title"),
            size: NSSize(width: 720, height: 560),
            rootView: AnyView(
                InsightsView()
                    .environmentObject(appState)
                    .frame(minWidth: 720, minHeight: 560)
            )
        )
    }

    private func showWindow(title: String, size: NSSize, rootView: AnyView) {
        if window == nil {
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = title
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(size)
            window.center()
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)
            self.window = window
        } else if let hostingController = window?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = rootView
            window?.title = title
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

