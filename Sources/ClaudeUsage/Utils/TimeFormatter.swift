import Foundation

enum ClaudeTimeFormatter {
    static func menuBarText(minutes: Int?) -> String {
        guard let minutes else { return "--" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", mins))"
        }
        return "\(mins)m"
    }

    static func menuBarCountdown(to date: Date?, now: Date = .now) -> String {
        guard let date else { return "--" }

        let remaining = max(date.timeIntervalSince(now), 0)
        let totalSeconds = Int(remaining.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh%02d", hours, minutes)
        }

        if minutes > 0 {
            return String(format: "%02d:%02d", minutes, seconds)
        }

        return String(format: "00:%02d", seconds)
    }

    static func detailed(minutes: Int?) -> String {
        guard let minutes else { return "--" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)min"
        }
        return "\(mins)min"
    }

    static func countdown(to date: Date?, now: Date = .now) -> String {
        guard let date else { return "--" }

        let remaining = max(date.timeIntervalSince(now), 0)
        let totalSeconds = Int(remaining.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        }

        if minutes > 0 {
            return String(format: "%02dm %02ds", minutes, seconds)
        }

        return String(format: "%02ds", seconds)
    }

    static func relative(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func clockTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func intervalLabel(seconds: TimeInterval) -> String {
        let totalMinutes = max(Int(seconds / 60), 1)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }
}
