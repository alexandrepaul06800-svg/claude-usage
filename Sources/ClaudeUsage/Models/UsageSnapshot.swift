import Foundation

struct UsageSnapshot: Codable, Equatable {
    var status: UsageStatus
    var usedRatio: Double
    var remainingRatio: Double
    var resetAt: Date?
    var minutesToReset: Int?
    var weeklyUsedRatio: Double?
    var weeklyResetAt: Date?
    var lastUpdatedAt: Date
    var confidence: DataConfidence
    var errorMessage: String?

    static let empty = UsageSnapshot(
        status: .unknown,
        usedRatio: 0,
        remainingRatio: 1,
        resetAt: nil,
        minutesToReset: nil,
        weeklyUsedRatio: nil,
        weeklyResetAt: nil,
        lastUpdatedAt: .distantPast,
        confidence: .low,
        errorMessage: nil
    )

    var isStale: Bool {
        guard lastUpdatedAt != .distantPast else { return true }
        return Date().timeIntervalSince(lastUpdatedAt) > 30 * 60
    }
}

enum UsageStatus: String, Codable {
    case ok
    case warning
    case limitNear
    case unknown
    case authRequired
    case syncError
}

enum DataConfidence: String, Codable {
    case high
    case medium
    case low
}
