import Foundation

struct AppPreferences: Codable, Equatable {
    enum MenuBarDisplayMode: String, Codable, CaseIterable, Identifiable {
        case usageOnly
        case resetOnly
        case both

        var id: String { rawValue }

        var label: String {
            switch self {
            case .usageOnly: L10n.tr("preferences.menu_bar_display.usage_only")
            case .resetOnly: L10n.tr("preferences.menu_bar_display.reset_only")
            case .both: L10n.tr("preferences.menu_bar_display.both")
            }
        }
    }

    var menuBarDisplayMode: MenuBarDisplayMode = .both
    var refreshIntervalMinutes: Int = 5
    var launchAtLogin: Bool = false
    var warningThreshold: Double = 0.8
    var resetNotificationsEnabled: Bool = true
    var syncErrorNotificationsEnabled: Bool = true
    var usageNotificationsEnabled: Bool = true
}
