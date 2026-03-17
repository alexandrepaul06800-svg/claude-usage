import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var snapshot: UsageSnapshot
    @Published var preferences: AppPreferences
    @Published var connectionState: ConnectionState
    @Published var sessionKeyInput: String
    @Published var organizationID: String
    @Published var storedSessionKeyMask: String
    @Published var isRefreshing = false
    @Published var usageInsights: UsageInsights
    @Published var historyEntries: [HistoryEntry]
    @Published var diagnosticsSnapshot: DiagnosticsSnapshot
    @Published var fullPayloadText: String

    private let usageService: UsageDataService

    init(
        usageService: UsageDataService = UsageDataService()
    ) {
        let historyEntries = usageService.loadHistory()
        self.usageService = usageService
        self.snapshot = usageService.latestSnapshot
        self.preferences = usageService.preferences
        self.connectionState = usageService.connectionState
        self.sessionKeyInput = ""
        self.organizationID = usageService.organizationID
        self.storedSessionKeyMask = usageService.storedSessionKeyMasked
        self.historyEntries = historyEntries
        self.usageInsights = UsageInsights.build(from: historyEntries)
        self.diagnosticsSnapshot = usageService.loadDiagnosticsSnapshot()
        self.fullPayloadText = usageService.loadFullPayloadText()

        bind()

        Task {
            await usageService.start()
        }
    }

    func refreshNow() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await usageService.refreshNow(isManual: true)
    }

    func saveSessionKey() async {
        let trimmed = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await usageService.refreshNow(isManual: true)
        } else {
            await usageService.saveSessionKey(trimmed)
            sessionKeyInput = ""
        }
    }

    func clearSessionKey() async {
        sessionKeyInput = ""
        await usageService.clearSessionKey()
        organizationID = ""
        storedSessionKeyMask = ""
        diagnosticsSnapshot = usageService.loadDiagnosticsSnapshot()
        fullPayloadText = usageService.loadFullPayloadText()
    }

    func exportHistory() {
        usageService.exportHistory()
    }

    func exportLastUsagePayload() {
        usageService.exportLastUsagePayload()
    }

    func updateOrganizationID(_ value: String) {
        organizationID = value
        usageService.updateOrganizationID(value)
    }

    func openSettings() {
        SettingsWindowPresenter.shared.show(appState: self)
    }

    func openInsights() {
        InsightsWindowPresenter.shared.show(appState: self)
    }

    func openDiagnostics() {
        DiagnosticsWindowPresenter.shared.show(appState: self)
    }

    var needsOnboarding: Bool {
        !hasSessionKeyConfigured
    }

    var canAttemptFetch: Bool {
        hasSessionKeyConfigured
    }

    var hasSessionKeyConfigured: Bool {
        !storedSessionKeyMask.isEmpty || !sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasLastUsagePayload: Bool {
        usageService.hasLastUsagePayload
    }

    var averageGrowthRateText: String {
        if let value = usageInsights.averageGrowthPerHourPercent {
            return "\(value)%"
        }
        return L10n.tr("common.never")
    }

    var averageCycleUsageText: String {
        if let value = usageInsights.averageCycleUsagePercent {
            return "\(value)%"
        }
        return L10n.tr("popover.cycles.not_enough")
    }

    var averageCyclePeakText: String {
        if let value = usageInsights.averageCyclePeakPercent {
            return "\(value)%"
        }
        return L10n.tr("popover.cycles.short_history")
    }

    var observedCyclesText: String {
        L10n.tr("popover.cycles.observed", usageInsights.observedCycles)
    }

    var currentRefreshIntervalText: String {
        ClaudeTimeFormatter.intervalLabel(seconds: usageService.currentRefreshInterval)
    }

    func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
        var updated = preferences
        mutate(&updated)
        usageService.updatePreferences(updated)
    }

    private func bind() {
        usageService.onSnapshotChange = { [weak self] snapshot in
            guard let self else { return }
            snapshotUpdate(snapshot)
        }
        usageService.onPreferencesChange = { [weak self] preferences in
            self?.preferences = preferences
        }
        usageService.onConnectionStateChange = { [weak self] connectionState in
            self?.connectionState = connectionState
            self?.storedSessionKeyMask = self?.usageService.storedSessionKeyMasked ?? ""
            self?.diagnosticsSnapshot = self?.usageService.loadDiagnosticsSnapshot() ?? .empty
        }
    }

    private func snapshotUpdate(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        self.historyEntries = usageService.loadHistory()
        self.usageInsights = UsageInsights.build(from: historyEntries)
        self.diagnosticsSnapshot = usageService.loadDiagnosticsSnapshot()
        self.fullPayloadText = usageService.loadFullPayloadText()
    }
}

enum ConnectionState: Equatable {
    case connected
    case disconnected
    case testing
    case failed(String)

    var label: String {
        switch self {
        case .connected: L10n.tr("connection_state.connected")
        case .disconnected: L10n.tr("connection_state.disconnected")
        case .testing: L10n.tr("connection_state.testing")
        case .failed(let message): message
        }
    }
}
