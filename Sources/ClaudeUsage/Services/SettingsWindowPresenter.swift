import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func show(appState: AppState) {
        if window == nil {
            let hostingController = NSHostingController(
                rootView: makeRootView(appState: appState)
            )

            let window = NSWindow(contentViewController: hostingController)
            window.title = L10n.tr("settings.window_title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 540, height: 420))
            window.center()
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)
            self.window = window
        } else if let hostingController = window?.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = makeRootView(appState: appState)
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func makeRootView(appState: AppState) -> AnyView {
        AnyView(
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 540, minHeight: 420)
        )
    }
}
