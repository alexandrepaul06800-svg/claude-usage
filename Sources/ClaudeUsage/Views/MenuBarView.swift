import Combine
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var now = Date()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusSymbol)
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(menuBarLabel(now: now))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .fixedSize()
        .help(accessibilitySummary(now: now))
        .onReceive(timer) { value in
            now = value
        }
    }

    private func menuBarLabel(now: Date) -> String {
        switch appState.preferences.menuBarDisplayMode {
        case .usageOnly:
            return usageText
        case .resetOnly:
            return resetLabel(now: now)
        case .both:
            return combinedLabel(now: now)
        }
    }

    private func combinedLabel(now: Date) -> String {
        let reset = resetText(now: now)

        if reset == placeholderReset {
            return usageText
        }

        return "\(usageText) · \(reset)"
    }

    private var usageText: String {
        switch appState.snapshot.status {
        case .ok, .warning, .limitNear:
            return "\(Int(appState.snapshot.usedRatio * 100))%"
        case .authRequired:
            return L10n.tr("menu_bar.status.login")
        case .syncError:
            return L10n.tr("menu_bar.status.error")
        case .unknown:
            return L10n.tr("menu_bar.status.setup")
        }
    }

    private func resetLabel(now: Date) -> String {
        let reset = resetText(now: now)
        return reset == placeholderReset ? usageText : reset
    }

    private func resetText(now: Date) -> String {
        let reset = ClaudeTimeFormatter.menuBarCountdown(to: appState.snapshot.resetAt, now: now)
        return reset == "--" ? placeholderReset : reset
    }

    private var placeholderReset: String {
        L10n.tr("menu_bar.status.pending")
    }

    private var statusSymbol: String {
        switch appState.snapshot.status {
        case .ok, .warning, .limitNear:
            return "chart.bar.fill"
        case .unknown:
            return "questionmark.circle"
        case .authRequired:
            return "key.fill"
        case .syncError:
            return "exclamationmark.triangle.fill"
        }
    }

    private func accessibilitySummary(now: Date) -> String {
        switch appState.preferences.menuBarDisplayMode {
        case .usageOnly:
            return usageText
        case .resetOnly:
            return resetLabel(now: now)
        case .both:
            return "\(usageText), \(resetLabel(now: now))"
        }
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: refreshCadence, on: .main, in: .common)
            .autoconnect()
    }

    private var refreshCadence: TimeInterval {
        switch appState.preferences.menuBarDisplayMode {
        case .usageOnly:
            return 30
        case .resetOnly, .both:
            guard let resetAt = appState.snapshot.resetAt else { return 30 }
            return resetAt.timeIntervalSinceNow <= 60 * 60 ? 1 : 30
        }
    }
}
