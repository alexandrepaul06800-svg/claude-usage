import AppKit
import Foundation

final class UsageDebugStore {
    private let fileManager = FileManager.default
    private let storageURL: URL
    private let maxPreviewCharacters: Int

    init(storageURL: URL? = nil, maxPreviewCharacters: Int = 2_500) {
        self.storageURL = storageURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsage", isDirectory: true)
            .appendingPathComponent("last-usage-response.json")
        self.maxPreviewCharacters = maxPreviewCharacters
    }

    func saveUsagePayload(_ data: Data) {
        do {
            try fileManager.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("UsageDebugStore save error: \(error.localizedDescription)")
        }
    }

    @MainActor
    func exportUsagePayload() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-usage-response.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? fileManager.removeItem(at: url)
            try? fileManager.copyItem(at: storageURL, to: url)
        }
    }

    var hasSavedPayload: Bool {
        fileManager.fileExists(atPath: storageURL.path)
    }

    func loadUsagePayload() -> Data? {
        try? Data(contentsOf: storageURL)
    }

    func loadUsagePayloadString() -> String {
        guard let data = loadUsagePayload() else { return "" }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: prettyData, encoding: .utf8) {
            return string
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func loadUsagePayloadPreview() -> String {
        let string = loadUsagePayloadString()
        guard string.count > maxPreviewCharacters else { return string }
        let index = string.index(string.startIndex, offsetBy: maxPreviewCharacters)
        return String(string[..<index]) + "\n\n" + L10n.tr("diagnostics.payload.truncated")
    }

    func clear() {
        try? fileManager.removeItem(at: storageURL)
    }
}
