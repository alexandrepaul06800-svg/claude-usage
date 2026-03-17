import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [claudeBackground, claudeSecondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryGrid
                    chartSection
                    historySection
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("insights.window_title"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)

            Text(appState.usageInsights.periodDetail)
                .font(.system(size: 13))
                .foregroundStyle(claudeTextSecondary)
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 14) {
            summaryCard(
                title: L10n.tr("popover.metric.average"),
                value: "\(appState.usageInsights.averageUsagePercent)%",
                detail: appState.usageInsights.usesRecentWindow
                    ? L10n.tr("popover.metric.average_detail_recent")
                    : L10n.tr("popover.metric.average_detail_history")
            )
            summaryCard(
                title: L10n.tr("popover.metric.pace"),
                value: appState.averageGrowthRateText,
                detail: L10n.tr("popover.metric.per_hour")
            )
            summaryCard(
                title: L10n.tr("popover.metric.per_cycle"),
                value: appState.averageCycleUsageText,
                detail: appState.observedCyclesText
            )
            summaryCard(
                title: L10n.tr("popover.detail.average_peak"),
                value: appState.averageCyclePeakText,
                detail: L10n.tr("insights.card.average_peak_detail")
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("insights.chart.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)

            GeometryReader { geometry in
                let ratios = appState.usageInsights.recentRatios
                let points = normalizedPoints(ratios: ratios, size: geometry.size)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(claudeCard.opacity(0.92))

                    VStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Divider()
                                .overlay(.white.opacity(0.06))
                            Spacer()
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)

                    if points.count >= 2 {
                        InsightsArea(points: points)
                            .fill(
                                LinearGradient(
                                    colors: [claudeAmber.opacity(0.28), claudeAmber.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        InsightsCurve(points: points)
                            .stroke(claudeAmber, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            Circle()
                                .fill(.white.opacity(0.8))
                                .frame(width: 5, height: 5)
                                .position(point)
                        }
                    } else {
                        Text(L10n.tr("popover.sparkline.empty"))
                            .font(.system(size: 13))
                            .foregroundStyle(claudeTextSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: 240)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("insights.history.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(claudeTextPrimary)

            VStack(spacing: 10) {
                ForEach(appState.historyEntries.suffix(12).reversed(), id: \.timestamp) { entry in
                    HStack {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(claudeTextSecondary)

                        Spacer()

                        Text("\(Int(entry.usedRatio * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(claudeTextPrimary)

                        Text(entry.status.rawValue.capitalized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(colorForUsage(entry.usedRatio))
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(claudeCard.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(claudeTextSecondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold))
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

    private func normalizedPoints(ratios: [Double], size: CGSize) -> [CGPoint] {
        guard ratios.count >= 2 else { return [] }

        let horizontalInset: CGFloat = 24
        let verticalInset: CGFloat = 24
        let usableWidth = max(size.width - (horizontalInset * 2), 1)
        let usableHeight = max(size.height - (verticalInset * 2), 1)
        let step = usableWidth / CGFloat(max(ratios.count - 1, 1))

        return ratios.enumerated().map { index, ratio in
            CGPoint(
                x: horizontalInset + (CGFloat(index) * step),
                y: verticalInset + ((1 - CGFloat(ratio)) * usableHeight)
            )
        }
    }
}

private struct InsightsCurve: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct InsightsArea: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        path.move(to: CGPoint(x: first.x, y: rect.maxY))
        path.addLine(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

