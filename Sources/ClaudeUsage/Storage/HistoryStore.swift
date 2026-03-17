import AppKit
import Foundation

struct HistoryEntry: Codable {
    let timestamp: Date
    let usedRatio: Double
    let minutesToReset: Int?
    let status: UsageStatus
}

final class HistoryStore {
    private let fileManager = FileManager.default
    private let maxEntries: Int
    private let storageURL: URL

    init(storageURL: URL? = nil, maxEntries: Int = 500) {
        self.maxEntries = maxEntries
        self.storageURL = storageURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsage", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    func load() -> [HistoryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: storageURL),
            let entries = try? decoder.decode([HistoryEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    func append(snapshot: UsageSnapshot) {
        var entries = load()
        entries.append(
            HistoryEntry(
                timestamp: snapshot.lastUpdatedAt,
                usedRatio: snapshot.usedRatio,
                minutesToReset: snapshot.minutesToReset,
                status: snapshot.status
            )
        )
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        save(entries)
    }

    @MainActor
    func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "claude-usage-history.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? fileManager.removeItem(at: url)
            try? fileManager.copyItem(at: storageURL, to: url)
        }
    }

    private func save(_ entries: [HistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            try fileManager.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("HistoryStore save error: \(error.localizedDescription)")
        }
    }
}
