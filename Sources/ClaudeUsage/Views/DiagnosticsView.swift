import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var revealPayload = false

    var body: some View {
        let diagnostics = appState.diagnosticsSnapshot

        ZStack {
            LinearGradient(
                colors: [claudeBackground, claudeSecondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("diagnostics.window_title"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(claudeTextPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        diagnosticCard(
                            title: L10n.tr("diagnostics.card.session"),
                            value: diagnostics.sessionState,
                            detail: diagnostics.authHint
                        )
                        diagnosticCard(
                            title: L10n.tr("diagnostics.card.organization"),
                            value: diagnostics.organizationID,
                            detail: L10n.tr("diagnostics.organization.help")
                        )
                        diagnosticCard(
                            title: L10n.tr("diagnostics.card.refresh"),
                            value: appState.currentRefreshIntervalText,
                            detail: diagnostics.networkHint
                        )
                        diagnosticCard(
                            title: L10n.tr("diagnostics.card.confidence"),
                            value: diagnostics.confidenceLabel,
                            detail: diagnostics.confidenceDetail
                        )
                    }

                    diagnosticGroup(title: L10n.tr("diagnostics.section.sync")) {
                        row(L10n.tr("diagnostics.row.last_success"), value: formatted(diagnostics.lastSuccessfulRefreshAt))
                        row(L10n.tr("diagnostics.row.last_attempt"), value: formatted(diagnostics.lastRefreshAttemptAt))
                        row(L10n.tr("diagnostics.row.connection"), value: appState.connectionState.label)
                        row(L10n.tr("diagnostics.row.last_error"), value: diagnostics.lastError ?? L10n.tr("diagnostics.none"))
                    }

                    diagnosticGroup(title: L10n.tr("diagnostics.section.payload")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(diagnostics.payloadAvailable ? L10n.tr("diagnostics.payload.available") : L10n.tr("diagnostics.payload.unavailable"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(claudeTextPrimary)
                                Text(L10n.tr("diagnostics.payload.characters", diagnostics.payloadCharacterCount))
                                    .font(.system(size: 12))
                                    .foregroundStyle(claudeTextSecondary)
                            }

                            Spacer()

                            Toggle(L10n.tr("diagnostics.payload.reveal"), isOn: $revealPayload)
                                .toggleStyle(.switch)
                                .disabled(!diagnostics.payloadAvailable)
                        }

                        ScrollView {
                            Text(revealPayload ? appState.fullPayloadText : diagnostics.payloadPreview)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(claudeTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                        .frame(minHeight: 240)
                        .background(.black.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 10) {
                            Button(L10n.tr("diagnostics.action.export_payload")) {
                                appState.exportLastUsagePayload()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!diagnostics.payloadAvailable)

                            Button(L10n.tr("diagnostics.action.export_history")) {
                                appState.exportHistory()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func diagnosticCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(claudeTextSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(claudeTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(claudeCard.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func diagnosticGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)
            VStack(alignment: .leading, spacing: 10, content: content)
                .padding(16)
                .background(claudeCard.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(claudeTextSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(claudeTextPrimary)
        }
        .font(.system(size: 12))
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return L10n.tr("diagnostics.none") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
