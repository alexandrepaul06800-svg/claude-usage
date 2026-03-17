import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let center: UNUserNotificationCenter?
    private let onSend: ((String, String) -> Void)?

    init(onSend: ((String, String) -> Void)? = nil) {
        self.onSend = onSend
        // `swift run` launches the raw binary from `.build/`, which is not a real app bundle.
        // UserNotifications crashes in that environment, so we only enable it for bundled app runs.
        if Bundle.main.bundleURL.pathExtension == "app" {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
    }

    func requestAuthorizationIfNeeded() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func send(title: String, body: String) {
        onSend?(title, body)
        guard let center else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
