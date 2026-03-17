import Foundation

struct UsageInsights {
    let recentRatios: [Double]
    let averageUsagePercent: Int
    let averageCyclePeakPercent: Int?
    let averageCycleUsagePercent: Int?
    let averageGrowthPerHourPercent: Int?
    let observedCycles: Int
    let periodLabel: String
    let periodDetail: String
    let usesRecentWindow: Bool

    static let empty = UsageInsights(
        recentRatios: [],
        averageUsagePercent: 0,
        averageCyclePeakPercent: nil,
        averageCycleUsagePercent: nil,
        averageGrowthPerHourPercent: nil,
        observedCycles: 0,
        periodLabel: L10n.tr("insights.period.recent_history"),
        periodDetail: L10n.tr("insights.period.not_enough_data"),
        usesRecentWindow: false
    )

    static func build(from entries: [HistoryEntry], now: Date = .now) -> UsageInsights {
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return .empty }

        let last24Hours = sorted.filter { now.timeIntervalSince($0.timestamp) <= 24 * 60 * 60 }
        let usesRecentWindow = !last24Hours.isEmpty
        let graphSource = usesRecentWindow ? last24Hours : Array(sorted.suffix(24))
        let graphRatios = sampledRatios(from: graphSource, limit: 18)
        let averageUsagePercent = Int((graphSource.map(\.usedRatio).average ?? 0) * 100)

        let cycleWindow = sorted.filter { now.timeIntervalSince($0.timestamp) <= 7 * 24 * 60 * 60 }
        let cycles = splitIntoCycles(cycleWindow)
        let cyclePeaks = cycles.compactMap { cycle in
            cycle.map(\.usedRatio).max()
        }
        let cycleUsage: [Double] = cycles.compactMap { cycle -> Double? in
            guard let first = cycle.first?.usedRatio, let peak = cycle.map(\.usedRatio).max() else {
                return nil
            }
            return max(peak - first, 0)
        }

        let averageCyclePeakPercent = cyclePeaks.isEmpty ? nil : Int((cyclePeaks.average ?? 0) * 100)
        let averageCycleUsagePercent = cycleUsage.isEmpty ? nil : Int((cycleUsage.average ?? 0) * 100)
        let averageGrowthPerHourPercent = averageGrowthPerHour(from: graphSource)

        return UsageInsights(
            recentRatios: graphRatios,
            averageUsagePercent: averageUsagePercent,
            averageCyclePeakPercent: averageCyclePeakPercent,
            averageCycleUsagePercent: averageCycleUsagePercent,
            averageGrowthPerHourPercent: averageGrowthPerHourPercent,
            observedCycles: cyclePeaks.count,
            periodLabel: periodLabel(for: graphSource, usesRecentWindow: usesRecentWindow),
            periodDetail: periodDetail(for: graphSource, usesRecentWindow: usesRecentWindow, now: now),
            usesRecentWindow: usesRecentWindow
        )
    }

    private static func periodLabel(for entries: [HistoryEntry], usesRecentWindow: Bool) -> String {
        if usesRecentWindow {
            return L10n.tr("insights.period.last_24_hours")
        }

        return entries.count <= 1
            ? L10n.tr("insights.period.latest_point")
            : L10n.tr("insights.period.latest_samples")
    }

    private static func periodDetail(for entries: [HistoryEntry], usesRecentWindow: Bool, now: Date) -> String {
        guard let first = entries.first, let last = entries.last else {
            return L10n.tr("insights.period.not_enough_data")
        }

        if usesRecentWindow {
            let sampleCount = entries.count
            return L10n.tr("insights.period.recent_samples_detail", sampleCount)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return L10n.tr(
            "insights.period.latest_samples_detail",
            formatter.localizedString(for: first.timestamp, relativeTo: now),
            formatter.localizedString(for: last.timestamp, relativeTo: now)
        )
    }

    private static func sampledRatios(from entries: [HistoryEntry], limit: Int) -> [Double] {
        guard entries.count > limit else { return entries.map(\.usedRatio) }

        let step = Double(entries.count - 1) / Double(limit - 1)
        return (0..<limit).map { index in
            let sampledIndex = Int((Double(index) * step).rounded())
            return entries[min(sampledIndex, entries.count - 1)].usedRatio
        }
    }

    private static func splitIntoCycles(_ entries: [HistoryEntry]) -> [[HistoryEntry]] {
        guard var current = entries.first.map({ [$0] }) else { return [] }

        var cycles: [[HistoryEntry]] = []

        for entry in entries.dropFirst() {
            let previous = current[current.count - 1]
            let usageDropped = previous.usedRatio - entry.usedRatio > 0.18
            let resetJumped = (entry.minutesToReset ?? 0) - (previous.minutesToReset ?? 0) > 45
            let largeGap = entry.timestamp.timeIntervalSince(previous.timestamp) > 8 * 60 * 60

            if usageDropped || resetJumped || largeGap {
                cycles.append(current)
                current = [entry]
            } else {
                current.append(entry)
            }
        }

        cycles.append(current)
        return cycles.filter { $0.count >= 2 }
    }

    private static func averageGrowthPerHour(from entries: [HistoryEntry]) -> Int? {
        guard entries.count >= 2 else { return nil }

        var accumulatedDelta = 0.0
        var accumulatedHours = 0.0

        for pair in zip(entries, entries.dropFirst()) {
            let delta = pair.1.usedRatio - pair.0.usedRatio
            let hours = pair.1.timestamp.timeIntervalSince(pair.0.timestamp) / 3600

            guard delta >= 0, delta <= 0.25, hours > 0, hours <= 6 else { continue }

            accumulatedDelta += delta
            accumulatedHours += hours
        }

        guard accumulatedHours > 0 else { return nil }
        return Int((accumulatedDelta / accumulatedHours) * 100)
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
