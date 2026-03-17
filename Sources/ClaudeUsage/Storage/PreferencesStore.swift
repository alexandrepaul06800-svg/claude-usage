import Foundation

final class PreferencesStore {
    private let defaults = UserDefaults.standard
    private let key = "com.claudeusage.preferences"

    func load() -> AppPreferences {
        guard
            let data = defaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else {
            return AppPreferences()
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: key)
        }
    }
}
