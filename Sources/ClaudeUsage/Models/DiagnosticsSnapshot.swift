import Foundation

struct DiagnosticsSnapshot {
    let sessionState: String
    let organizationID: String
    let lastSuccessfulRefreshAt: Date?
    let lastRefreshAttemptAt: Date?
    let currentRefreshInterval: TimeInterval
    let lastError: String?
    let confidenceLabel: String
    let confidenceDetail: String
    let payloadAvailable: Bool
    let payloadPreview: String
    let payloadCharacterCount: Int
    let networkHint: String
    let authHint: String

    static let empty = DiagnosticsSnapshot(
        sessionState: L10n.tr("diagnostics.session.not_configured"),
        organizationID: L10n.tr("diagnostics.organization.auto"),
        lastSuccessfulRefreshAt: nil,
        lastRefreshAttemptAt: nil,
        currentRefreshInterval: 5 * 60,
        lastError: nil,
        confidenceLabel: L10n.tr("popover.confidence.low"),
        confidenceDetail: L10n.tr("popover.confidence.to_confirm"),
        payloadAvailable: false,
        payloadPreview: L10n.tr("diagnostics.payload.empty"),
        payloadCharacterCount: 0,
        networkHint: L10n.tr("diagnostics.network.normal"),
        authHint: L10n.tr("diagnostics.auth.waiting")
    )
}

