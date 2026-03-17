import XCTest
@testable import ClaudeUsage

@MainActor
final class UsageDataServiceTests: XCTestCase {
    func testResetNotificationDoesNotDependOnUsageNotificationsToggle() {
        let service = UsageDataService(notificationService: NotificationService())
        service.updatePreferences(
            AppPreferences(
                menuBarDisplayMode: .both,
                refreshIntervalMinutes: 5,
                launchAtLogin: false,
                warningThreshold: 0.8,
                resetNotificationsEnabled: true,
                syncErrorNotificationsEnabled: false,
                usageNotificationsEnabled: false
            )
        )

        let messages = service.notificationMessages(
            previousSnapshot: UsageSnapshot(
                status: .warning,
                usedRatio: 0.6,
                remainingRatio: 0.4,
                resetAt: nil,
                minutesToReset: 5,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: .now,
                confidence: .high,
                errorMessage: nil
            ),
            newSnapshot: UsageSnapshot(
                status: .ok,
                usedRatio: 0.05,
                remainingRatio: 0.95,
                resetAt: nil,
                minutesToReset: 295,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: .now,
                confidence: .high,
                errorMessage: nil
            ),
            lastStatus: .warning
        )

        XCTAssertEqual(messages, [L10n.tr("notification.window_reset")])
    }

    func testUsageWarningNotificationRespectsThreshold() {
        let service = UsageDataService(notificationService: NotificationService())
        service.updatePreferences(AppPreferences(warningThreshold: 0.7))

        let messages = service.notificationMessages(
            previousSnapshot: .empty,
            newSnapshot: UsageSnapshot(
                status: .warning,
                usedRatio: 0.75,
                remainingRatio: 0.25,
                resetAt: nil,
                minutesToReset: 40,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: .now,
                confidence: .high,
                errorMessage: nil
            ),
            lastStatus: .ok
        )

        XCTAssertEqual(messages, [L10n.tr("notification.usage_consumed", 75)])
    }

    func testResetNotificationRequiresObservedResetSignal() {
        let service = UsageDataService(notificationService: NotificationService())

        let messages = service.notificationMessages(
            previousSnapshot: UsageSnapshot(
                status: .warning,
                usedRatio: 0.65,
                remainingRatio: 0.35,
                resetAt: nil,
                minutesToReset: 15,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: Date(timeIntervalSinceNow: -(10 * 60 * 60)),
                confidence: .high,
                errorMessage: nil
            ),
            newSnapshot: UsageSnapshot(
                status: .ok,
                usedRatio: 0.04,
                remainingRatio: 0.96,
                resetAt: nil,
                minutesToReset: 300,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: .now,
                confidence: .high,
                errorMessage: nil
            ),
            lastStatus: .warning
        )

        XCTAssertTrue(messages.isEmpty)
    }
}
