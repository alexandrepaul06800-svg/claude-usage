import Foundation

enum AppMetadata {
    static let fallbackVersion = "0.2.0"

    static var displayVersion: String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bundleVersion
        }

        return fallbackVersion
    }
}
