import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [claudeBackground, claudeSecondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if appState.needsOnboarding {
                        onboardingCard
                    } else {
                        heroCard
                        if let errorMessage = appState.snapshot.errorMessage {
                            alertCard(errorMessage)
                        }
                        quickStats
                        quickLinks
                    }

                    footerActions
                }
                .padding(18)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("app.name"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(claudeTextPrimary)

                Text(toplineText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(claudeTextSecondary)
            }

            Spacer()

            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(claudeTextPrimary)
                    .frame(width: 34, height: 34)
                    .background(claudeCard.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(heroEyebrow)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(claudeTextSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(appState.snapshot.usedRatio * 100))%")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(claudeTextPrimary)
                        Text(L10n.tr("popover.hero.used"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(claudeTextSecondary)
                    }
                }

                Spacer()

                statusPill(statusLabel, tint: statusTint)
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(colorForUsage(appState.snapshot.usedRatio))
                            .frame(width: max(18, geometry.size.width * appState.snapshot.usedRatio), height: 12)
                    }
            }
            .frame(height: 12)

            HStack(spacing: 10) {
                infoChip(title: L10n.tr("popover.hero.reset"), value: ClaudeTimeFormatter.countdown(to: appState.snapshot.resetAt))
                infoChip(title: L10n.tr("popover.hero.remaining"), value: "\(Int(appState.snapshot.remainingRatio * 100))%")
            }

            Text(heroSummary)
                .font(.system(size: 13))
                .foregroundStyle(claudeTextSecondary)
        }
        .padding(16)
        .background(claudeCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var quickStats: some View {
        HStack(spacing: 10) {
            statCard(
                title: L10n.tr("popover.metric.average"),
                value: "\(appState.usageInsights.averageUsagePercent)%",
                detail: appState.usageInsights.periodLabel
            )
            statCard(
                title: L10n.tr("popover.metric.pace"),
                value: appState.averageGrowthRateText,
                detail: L10n.tr("popover.metric.per_hour")
            )
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("popover.section.more"))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(claudeTextSecondary)

            Button {
                appState.openInsights()
            } label: {
                linkRow(
                    title: L10n.tr("popover.link.insights_title"),
                    detail: L10n.tr("popover.link.insights_detail"),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .buttonStyle(.plain)

            Button {
                appState.openDiagnostics()
            } label: {
                linkRow(
                    title: L10n.tr("popover.link.diagnostics_title"),
                    detail: L10n.tr("popover.link.diagnostics_detail"),
                    icon: "waveform.path.ecg"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("popover.onboarding.connection_required"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)

            Text(L10n.tr("popover.onboarding.body"))
                .font(.system(size: 13))
                .foregroundStyle(claudeTextSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. " + L10n.tr("popover.onboarding.step_1"))
                Text("2. " + L10n.tr("popover.onboarding.step_2"))
                Text("3. " + L10n.tr("popover.onboarding.step_3"))
            }
            .font(.system(size: 12))
            .foregroundStyle(claudeTextSecondary)

            Button {
                appState.openSettings()
            } label: {
                primaryButton(L10n.tr("popover.action.configure_connection"), icon: "key.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(claudeCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button {
                appState.openSettings()
            } label: {
                secondaryButton(L10n.tr("popover.action.preferences"), icon: "slider.horizontal.3")
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.refreshNow() }
            } label: {
                primaryButton(
                    appState.isRefreshing ? L10n.tr("popover.action.refreshing") : L10n.tr("popover.action.refresh"),
                    icon: appState.isRefreshing ? "hourglass" : "arrow.clockwise"
                )
            }
            .buttonStyle(.plain)
            .disabled(appState.isRefreshing)
        }
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(claudeTextSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(claudeTextSecondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(claudeTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(claudeCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func linkRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(claudeAmber)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(claudeTextPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(claudeTextSecondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .foregroundStyle(claudeTextSecondary)
        }
        .padding(14)
        .background(claudeCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func alertCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(claudeAmber)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(claudeTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(claudeAmber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func primaryButton(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(claudeAmber)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func secondaryButton(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(claudeTextPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(claudeCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusTint: Color {
        switch appState.snapshot.status {
        case .ok: claudeGreen
        case .warning: claudeYellow
        case .limitNear: claudeRed
        case .authRequired, .syncError: claudeAmber
        case .unknown: claudeTextSecondary
        }
    }

    private var statusLabel: String {
        switch appState.snapshot.status {
        case .ok: L10n.tr("popover.status.fluid")
        case .warning: L10n.tr("popover.status.watch")
        case .limitNear: L10n.tr("popover.status.near_limit")
        case .syncError: L10n.tr("popover.status.sync_error")
        case .authRequired: L10n.tr("popover.status.connection_required")
        case .unknown: L10n.tr("popover.status.pending")
        }
    }

    private var heroEyebrow: String {
        switch appState.snapshot.status {
        case .limitNear:
            return L10n.tr("popover.hero.high_zone")
        default:
            return L10n.tr("popover.hero.current_cycle")
        }
    }

    private var heroSummary: String {
        switch appState.snapshot.status {
        case .ok:
            return L10n.tr("popover.hero.summary.ok")
        case .warning:
            return L10n.tr("popover.hero.summary.warning")
        case .limitNear:
            return L10n.tr("popover.hero.summary.limit_near")
        case .authRequired:
            return L10n.tr("popover.hero.summary.auth_required")
        case .syncError:
            return L10n.tr("popover.hero.summary.sync_error")
        case .unknown:
            return L10n.tr("popover.hero.summary.unknown")
        }
    }

    private var toplineText: String {
        if appState.needsOnboarding {
            return L10n.tr("popover.topline.session_required")
        }
        if appState.connectionState == .testing {
            return L10n.tr("popover.topline.syncing")
        }
        if appState.snapshot.isStale {
            return L10n.tr("popover.topline.needs_confirmation")
        }
        return L10n.tr("popover.topline.simple_read")
    }
}
