import XCTest
@testable import ClaudeUsage

final class HistoryStoreTests: XCTestCase {
    func testHistoryRoundTripUsesISO8601Dates() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let store = HistoryStore(storageURL: url, maxEntries: 10)

        let snapshot = UsageSnapshot(
            status: .warning,
            usedRatio: 0.42,
            remainingRatio: 0.58,
            resetAt: nil,
            minutesToReset: 87,
            weeklyUsedRatio: nil,
            weeklyResetAt: nil,
            lastUpdatedAt: Date(timeIntervalSince1970: 1_715_000_000),
            confidence: .medium,
            errorMessage: nil
        )

        store.append(snapshot: snapshot)
        let entries = store.load()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].usedRatio, 0.42, accuracy: 0.0001)
        XCTAssertEqual(entries[0].minutesToReset, 87)
        XCTAssertEqual(entries[0].timestamp, snapshot.lastUpdatedAt)
    }

    func testHistoryRetentionCapIsApplied() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let store = HistoryStore(storageURL: url, maxEntries: 3)

        for index in 0..<5 {
            store.append(
                snapshot: UsageSnapshot(
                    status: .ok,
                    usedRatio: Double(index) / 10,
                    remainingRatio: 1 - (Double(index) / 10),
                    resetAt: nil,
                    minutesToReset: index,
                    weeklyUsedRatio: nil,
                    weeklyResetAt: nil,
                    lastUpdatedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                    confidence: .high,
                    errorMessage: nil
                )
            )
        }

        let entries = store.load()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.first?.minutesToReset, 2)
        XCTAssertEqual(entries.last?.minutesToReset, 4)
    }
}

