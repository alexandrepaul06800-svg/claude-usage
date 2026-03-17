import AppKit
import Foundation

@MainActor
final class UsageDataService {
    var onSnapshotChange: ((UsageSnapshot) -> Void)?
    var onPreferencesChange: ((AppPreferences) -> Void)?
    var onConnectionStateChange: ((ConnectionState) -> Void)?

    private let fetcher: ClaudeFetcher
    private let keychainStore: KeychainStore
    private let historyStore: HistoryStore
    private let usageDebugStore: UsageDebugStore
    private let preferencesStore: PreferencesStore
    private let notificationService: NotificationService
    private let launchAtLoginService: LaunchAtLoginService

    private var timer: Timer?
    private var errorCount = 0
    private var lastStatus: UsageStatus?
    private(set) var lastSuccessfulRefreshAt: Date?
    private(set) var lastRefreshAttemptAt: Date?
    private(set) var lastError: String?

    private(set) var latestSnapshot: UsageSnapshot
    private(set) var preferences: AppPreferences
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var organizationID: String {
        get { UserDefaults.standard.string(forKey: "com.claudeusage.organizationID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "com.claudeusage.organizationID") }
    }

    init(
        fetcher: ClaudeFetcher = ClaudeFetcher(),
        keychainStore: KeychainStore = KeychainStore(),
        historyStore: HistoryStore = HistoryStore(),
        usageDebugStore: UsageDebugStore = UsageDebugStore(),
        preferencesStore: PreferencesStore = PreferencesStore(),
        notificationService: NotificationService = NotificationService(),
        launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService()
    ) {
        self.fetcher = fetcher
        self.keychainStore = keychainStore
        self.historyStore = historyStore
        self.usageDebugStore = usageDebugStore
        self.preferencesStore = preferencesStore
        self.notificationService = notificationService
        self.launchAtLoginService = launchAtLoginService
        self.preferences = preferencesStore.load()
        self.latestSnapshot = historyStore.load().last.map {
            UsageSnapshot(
                status: $0.status,
                usedRatio: $0.usedRatio,
                remainingRatio: max(0, 1 - $0.usedRatio),
                resetAt: nil,
                minutesToReset: $0.minutesToReset,
                weeklyUsedRatio: nil,
                weeklyResetAt: nil,
                lastUpdatedAt: $0.timestamp,
                confidence: .low,
                errorMessage: nil
            )
        } ?? .empty

        if (try? keychainStore.load())?.isEmpty == false {
            connectionState = .connected
        }
    }

    var storedSessionKeyMasked: String {
        guard let key = try? keychainStore.load(), !key.isEmpty else {
            return ""
        }
        let suffix = key.suffix(4)
        return "••••••••\(suffix)"
    }

    func start() async {
        await notificationService.requestAuthorizationIfNeeded()
        scheduleTimer(with: currentRefreshInterval)
        if (try? keychainStore.load())?.isEmpty == false {
            await refreshNow(isManual: false)
        }
    }

    func refreshNow(isManual: Bool) async {
        timer?.invalidate()
        lastRefreshAttemptAt = .now

        guard let sessionKey = try? keychainStore.load(), !sessionKey.isEmpty else {
            connectionState = .disconnected
            lastError = L10n.tr("error.paste_session_key")
            onConnectionStateChange?(connectionState)
            updateSnapshot(
                UsageSnapshot(
                    status: .unknown,
                    usedRatio: latestSnapshot.usedRatio,
                    remainingRatio: latestSnapshot.remainingRatio,
                    resetAt: latestSnapshot.resetAt,
                    minutesToReset: latestSnapshot.minutesToReset,
                    weeklyUsedRatio: latestSnapshot.weeklyUsedRatio,
                    weeklyResetAt: latestSnapshot.weeklyResetAt,
                    lastUpdatedAt: latestSnapshot.lastUpdatedAt,
                    confidence: .low,
                    errorMessage: L10n.tr("error.paste_session_key")
                )
            )
            scheduleTimer(with: currentRefreshInterval)
            return
        }

        do {
            connectionState = .testing
            onConnectionStateChange?(connectionState)

            let response = try await fetcher.fetchUsage(
                sessionKey: sessionKey,
                organizationID: organizationID
            )
            var snapshot = response.snapshot
            if organizationID != response.organizationID {
                organizationID = response.organizationID
            }
            usageDebugStore.saveUsagePayload(response.rawPayload)
            if snapshot.isStale {
                snapshot.confidence = .low
            }

            errorCount = 0
            lastSuccessfulRefreshAt = snapshot.lastUpdatedAt
            lastError = nil
            connectionState = .connected
            onConnectionStateChange?(connectionState)
            handleNotifications(for: snapshot)
            historyStore.append(snapshot: snapshot)
            updateSnapshot(snapshot)
        } catch {
            errorCount += 1

            if let fetchError = error as? FetchError, fetchError == .authRequired {
                connectionState = .failed(L10n.tr("connection_state.invalid_session"))
                lastError = error.localizedDescription
                onConnectionStateChange?(connectionState)
                let snapshot = UsageSnapshot(
                    status: .authRequired,
                    usedRatio: latestSnapshot.usedRatio,
                    remainingRatio: latestSnapshot.remainingRatio,
                    resetAt: latestSnapshot.resetAt,
                    minutesToReset: latestSnapshot.minutesToReset,
                    weeklyUsedRatio: latestSnapshot.weeklyUsedRatio,
                    weeklyResetAt: latestSnapshot.weeklyResetAt,
                    lastUpdatedAt: latestSnapshot.lastUpdatedAt,
                    confidence: .low,
                    errorMessage: error.localizedDescription
                )
                updateSnapshot(snapshot)
            } else {
                connectionState = .failed(error.localizedDescription)
                lastError = error.localizedDescription
                onConnectionStateChange?(connectionState)
                let snapshot = UsageSnapshot(
                    status: .syncError,
                    usedRatio: latestSnapshot.usedRatio,
                    remainingRatio: latestSnapshot.remainingRatio,
                    resetAt: latestSnapshot.resetAt,
                    minutesToReset: latestSnapshot.minutesToReset,
                    weeklyUsedRatio: latestSnapshot.weeklyUsedRatio,
                    weeklyResetAt: latestSnapshot.weeklyResetAt,
                    lastUpdatedAt: latestSnapshot.lastUpdatedAt,
                    confidence: latestSnapshot.isStale ? .low : .medium,
                    errorMessage: error.localizedDescription
                )
                if preferences.syncErrorNotificationsEnabled, isManual == false {
                    notificationService.send(
                        title: L10n.tr("notification.title"),
                        body: L10n.tr("notification.sync_failed")
                    )
                }
                updateSnapshot(snapshot)
            }
        }

        scheduleTimer(with: currentRefreshInterval)
    }

    func saveSessionKey(_ sessionKey: String) async {
        let trimmed = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try keychainStore.save(trimmed)
            await refreshNow(isManual: true)
        } catch {
            connectionState = .failed(error.localizedDescription)
            onConnectionStateChange?(connectionState)
        }
    }

    func clearSessionKey() async {
        keychainStore.delete()
        usageDebugStore.clear()
        organizationID = ""
        lastError = nil
        lastRefreshAttemptAt = nil
        lastSuccessfulRefreshAt = nil
        lastStatus = nil
        connectionState = .disconnected
        onConnectionStateChange?(connectionState)
        updateSnapshot(.empty)
        scheduleTimer(with: currentRefreshInterval)
    }

    func updatePreferences(_ preferences: AppPreferences) {
        let previousPreferences = self.preferences
        self.preferences = preferences
        preferencesStore.save(preferences)

        if previousPreferences.launchAtLogin != preferences.launchAtLogin {
            do {
                try launchAtLoginService.setEnabled(preferences.launchAtLogin)
            } catch {
                NSLog("LaunchAtLogin toggle error: \(error.localizedDescription)")
            }
        }

        onPreferencesChange?(preferences)
        scheduleTimer(with: currentRefreshInterval)
    }

    func updateOrganizationID(_ value: String) {
        organizationID = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func exportHistory() {
        historyStore.exportHistory()
    }

    func exportLastUsagePayload() {
        usageDebugStore.exportUsagePayload()
    }

    var hasLastUsagePayload: Bool {
        usageDebugStore.hasSavedPayload
    }

    func loadHistory() -> [HistoryEntry] {
        historyStore.load()
    }

    func loadFullPayloadText() -> String {
        usageDebugStore.loadUsagePayloadString()
    }

    func loadDiagnosticsSnapshot() -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            sessionState: storedSessionKeyMasked.isEmpty ? L10n.tr("diagnostics.session.not_configured") : storedSessionKeyMasked,
            organizationID: organizationID.isEmpty ? L10n.tr("diagnostics.organization.auto") : organizationID,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            lastRefreshAttemptAt: lastRefreshAttemptAt,
            currentRefreshInterval: currentRefreshInterval,
            lastError: lastError,
            confidenceLabel: confidenceTitle(for: latestSnapshot.confidence),
            confidenceDetail: confidenceSubtitle(for: latestSnapshot.confidence),
            payloadAvailable: usageDebugStore.hasSavedPayload,
            payloadPreview: usageDebugStore.loadUsagePayloadPreview(),
            payloadCharacterCount: usageDebugStore.loadUsagePayloadString().count,
            networkHint: networkHint,
            authHint: authHint
        )
    }

    private func updateSnapshot(_ snapshot: UsageSnapshot) {
        latestSnapshot = snapshot
        onSnapshotChange?(snapshot)
    }

    var currentRefreshInterval: TimeInterval {
        switch latestSnapshot.status {
        case .warning:
            return 2 * 60
        case .syncError:
            return min(Double([1, 2, 5, 10][min(max(errorCount - 1, 0), 3)]), 10) * 60
        case .limitNear:
            return 2 * 60
        default:
            return Double(preferences.refreshIntervalMinutes) * 60
        }
    }

    private func scheduleTimer(with interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshNow(isManual: false)
            }
        }
    }

    private func handleNotifications(for snapshot: UsageSnapshot) {
        defer { lastStatus = snapshot.status }

        let messages = notificationMessages(previousSnapshot: latestSnapshot, newSnapshot: snapshot, lastStatus: lastStatus)
        for message in messages {
            notificationService.send(title: L10n.tr("notification.title"), body: message)
        }
    }

    func notificationMessages(previousSnapshot: UsageSnapshot, newSnapshot snapshot: UsageSnapshot, lastStatus: UsageStatus?) -> [String] {
        var messages: [String] = []

        if preferences.usageNotificationsEnabled,
           snapshot.usedRatio >= 0.95,
           lastStatus != .limitNear {
            messages.append(L10n.tr("notification.limit_near"))
        } else if preferences.usageNotificationsEnabled,
                  snapshot.usedRatio >= preferences.warningThreshold,
                  lastStatus == .ok || lastStatus == nil {
            messages.append(L10n.tr("notification.usage_consumed", Int(snapshot.usedRatio * 100)))
        }

        if preferences.resetNotificationsEnabled,
           looksLikeObservedReset(previousSnapshot: previousSnapshot, newSnapshot: snapshot) {
            messages.append(L10n.tr("notification.window_reset"))
        }

        return messages
    }

    private func confidenceTitle(for confidence: DataConfidence) -> String {
        switch confidence {
        case .high: L10n.tr("popover.confidence.high")
        case .medium: L10n.tr("popover.confidence.medium")
        case .low: L10n.tr("popover.confidence.low")
        }
    }

    private func confidenceSubtitle(for confidence: DataConfidence) -> String {
        switch confidence {
        case .high: L10n.tr("popover.confidence.reliable")
        case .medium: L10n.tr("popover.confidence.cautious")
        case .low: L10n.tr("popover.confidence.to_confirm")
        }
    }

    private var networkHint: String {
        if let error = lastError?.lowercased(), error.contains("network") || error.contains("connexion") {
            return L10n.tr("diagnostics.network.recovering")
        }
        return L10n.tr("diagnostics.network.normal")
    }

    private var authHint: String {
        switch latestSnapshot.status {
        case .authRequired:
            return L10n.tr("diagnostics.auth.invalid")
        case .unknown where storedSessionKeyMasked.isEmpty:
            return L10n.tr("diagnostics.auth.waiting")
        default:
            return L10n.tr("diagnostics.auth.valid")
        }
    }

    private func looksLikeObservedReset(previousSnapshot: UsageSnapshot, newSnapshot: UsageSnapshot) -> Bool {
        guard previousSnapshot.lastUpdatedAt != .distantPast else { return false }
        guard previousSnapshot.usedRatio > newSnapshot.usedRatio else { return false }
        guard newSnapshot.usedRatio < 0.1 else { return false }
        guard newSnapshot.lastUpdatedAt.timeIntervalSince(previousSnapshot.lastUpdatedAt) <= 8 * 60 * 60 else { return false }

        let previousMinutes = previousSnapshot.minutesToReset
        let newMinutes = newSnapshot.minutesToReset
        if let previousMinutes, let newMinutes {
            return newMinutes - previousMinutes > 45
        }

        return false
    }
}
