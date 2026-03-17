import Foundation

struct ClaudeFetcher {
    var session: URLSession = .shared
    var apiBaseURL: URL = URL(string: "https://claude.ai")!
    private let usageRequestTimeout: TimeInterval = 10
    private let organizationProbeTimeout: TimeInterval = 4

    func fetchUsage(sessionKey: String, organizationID: String?) async throws -> UsageResponse {
        let trimmedOrganizationID = organizationID?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedOrganizationID, !trimmedOrganizationID.isEmpty {
            do {
                return try await fetchUsage(
                    sessionKey: sessionKey,
                    resolvedOrganizationID: trimmedOrganizationID
                )
            } catch let FetchError.serverError(code) where code == 404 {
                if let detected = try await detectOrganizationID(sessionKey: sessionKey),
                   detected != trimmedOrganizationID {
                    do {
                        return try await fetchUsage(
                            sessionKey: sessionKey,
                            resolvedOrganizationID: detected
                        )
                    } catch let FetchError.serverError(code) where code == 404 {
                        throw FetchError.organizationNotFound
                    }
                }

                throw FetchError.organizationNotFound
            }
        }

        guard let detected = try await detectOrganizationID(sessionKey: sessionKey) else {
            throw FetchError.missingOrganizationID
        }

        do {
            return try await fetchUsage(
                sessionKey: sessionKey,
                resolvedOrganizationID: detected
            )
        } catch let FetchError.serverError(code) where code == 404 {
            throw FetchError.organizationNotFound
        }
    }

    private func fetchUsage(sessionKey: String, resolvedOrganizationID: String) async throws -> UsageResponse {
        let url = apiBaseURL.appending(path: "/api/organizations/\(resolvedOrganizationID)/usage")
        var request = URLRequest(url: url)
        request.timeoutInterval = usageRequestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

        let (data, response) = try await performRequest(request)

        switch response.statusCode {
        case 200:
            return UsageResponse(
                snapshot: try parseUsageResponse(data),
                organizationID: resolvedOrganizationID,
                rawPayload: data
            )
        case 401, 403:
            throw FetchError.authRequired
        case 429:
            throw FetchError.rateLimited
        default:
            throw FetchError.serverError(response.statusCode)
        }
    }

    func detectOrganizationID(sessionKey: String) async throws -> String? {
        let candidates = [
            "/api/organizations",
            "/api/bootstrap",
            "/api/account",
        ]
        var receivedHTTPResponse = false
        var timedOutRequests = 0

        for path in candidates {
            let url = apiBaseURL.appending(path: path)
            var request = URLRequest(url: url)
            request.timeoutInterval = organizationProbeTimeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
            request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")

            do {
                let (data, response) = try await performRequest(request)
                receivedHTTPResponse = true

                switch response.statusCode {
                case 200:
                    if let organizationID = parseOrganizationID(from: data, sourcePath: path) {
                        return organizationID
                    }
                case 401, 403:
                    throw FetchError.authRequired
                default:
                    continue
                }
            } catch let error as FetchError {
                switch error {
                case .authRequired, .networkUnavailable:
                    throw error
                case .timeout:
                    timedOutRequests += 1
                    continue
                default:
                    continue
                }
            } catch {
                continue
            }
        }

        if !receivedHTTPResponse, timedOutRequests == candidates.count {
            throw FetchError.timeout
        }

        return nil
    }

    func parseUsageResponse(_ data: Data) throws -> UsageSnapshot {
        let knownPayload = try? JSONDecoder().decode(KnownUsagePayload.self, from: data)
        let heuristicPayload = try UsagePayload(data: data)
        let usedRatio = knownPayload?.hasUsageSignals == true ? knownPayload?.usedRatioValue ?? heuristicPayload.usedRatioValue : heuristicPayload.usedRatioValue
        let resetAt = knownPayload?.hasUsageSignals == true ? knownPayload?.resetDate ?? heuristicPayload.resetDate : heuristicPayload.resetDate
        let minutesToReset = resetAt.map { max(Int($0.timeIntervalSinceNow / 60), 0) }
        let weeklyUsedRatio = knownPayload?.hasUsageSignals == true ? knownPayload?.weeklyUsedRatio ?? heuristicPayload.weeklyUsedRatio : heuristicPayload.weeklyUsedRatio
        let weeklyResetAt = knownPayload?.hasUsageSignals == true ? knownPayload?.weeklyResetDate ?? heuristicPayload.weeklyResetDate : heuristicPayload.weeklyResetDate

        return UsageSnapshot(
            status: statusForUsage(usedRatio),
            usedRatio: usedRatio,
            remainingRatio: max(0, 1 - usedRatio),
            resetAt: resetAt,
            minutesToReset: minutesToReset,
            weeklyUsedRatio: weeklyUsedRatio,
            weeklyResetAt: weeklyResetAt,
            lastUpdatedAt: .now,
            confidence: .high,
            errorMessage: nil
        )
    }

    func parseOrganizationID(from data: Data, sourcePath: String) -> String? {
        if let known = try? JSONDecoder().decode(KnownOrganizationEnvelope.self, from: data),
           let organizationID = known.detectedOrganizationID {
            return organizationID
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let initialContext = sourcePath.contains("organizations") ? "organizations" : nil

        if let direct = extractOrganizationID(from: root, contextKey: initialContext) {
            return direct
        }

        return nil
    }

    private func extractOrganizationID(from value: Any, contextKey: String?) -> String? {
        if let dictionary = value as? [String: Any] {
            let directKeys = [
                "organization_id",
                "organizationId",
                "organization_uuid",
                "organizationUuid",
                "active_organization_id",
                "activeOrganizationId",
                "active_organization_uuid",
                "activeOrganizationUuid",
                "selected_organization_id",
                "selectedOrganizationId",
            ]
            let typeValue = (dictionary["type"] as? String)?.lowercased()

            for key in directKeys {
                if let stringValue = dictionary[key] as? String, looksLikeOrganizationID(stringValue, type: typeValue, key: key) {
                    return stringValue
                }
            }

            if let stringValue = dictionary["id"] as? String,
               looksLikeOrganizationID(stringValue, type: typeValue, key: "id", contextKey: contextKey) {
                return stringValue
            }

            let nestedKeys = [
                "organization",
                "activeOrganization",
                "active_organization",
                "currentOrganization",
                "current_organization",
                "selectedOrganization",
                "selected_organization",
                "defaultOrganization",
                "organizations",
                "memberships",
                "data",
                "items",
                "results",
            ]
            for key in nestedKeys {
                let nextContext: String?
                if ["data", "items", "results"].contains(key), contextKey != nil {
                    nextContext = contextKey
                } else {
                    nextContext = key
                }

                if let nested = dictionary[key], let match = extractOrganizationID(from: nested, contextKey: nextContext) {
                    return match
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let match = extractOrganizationID(from: item, contextKey: contextKey) {
                    return match
                }
            }
        }

        return nil
    }

    private func looksLikeOrganizationID(_ value: String, type: String?, key: String, contextKey: String? = nil) -> Bool {
        if key == "id" {
            if let type, type.contains("organization") {
                return true
            }

            let normalizedContext = contextKey?
                .replacingOccurrences(of: "_", with: "")
                .lowercased()

            if let normalizedContext, normalizedContext.contains("organization") {
                return true
            }

            return false
        }
        return !value.isEmpty
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            return (data, response)
        } catch let error as FetchError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw FetchError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw FetchError.networkUnavailable
            default:
                throw error
            }
        }
    }
}

private struct KnownUsagePayload: Decodable {
    let sessionUsedRatio: Double?
    let currentSessionUsedRatio: Double?
    let fiveHourUsedRatio: Double?
    let fiveHour: KnownFiveHourUsage?
    let sessionResetAt: String?
    let currentResetAt: String?
    let resetAt: String?
    let sevenDay: KnownSevenDayUsage?

    enum CodingKeys: String, CodingKey {
        case sessionUsedRatio = "session_used_ratio"
        case currentSessionUsedRatio = "current_session_used_ratio"
        case fiveHourUsedRatio = "five_hour_used_ratio"
        case fiveHour = "five_hour"
        case sessionResetAt = "session_reset_at"
        case currentResetAt = "current_reset_at"
        case resetAt = "reset_at"
        case sevenDay = "seven_day"
    }

    var usedRatioValue: Double {
        let ratio = sessionUsedRatio
            ?? currentSessionUsedRatio
            ?? fiveHourUsedRatio
            ?? fiveHour?.utilization.map { $0 / 100 }
            ?? 0
        return min(max(ratio, 0), 1)
    }

    var hasUsageSignals: Bool {
        sessionUsedRatio != nil
            || currentSessionUsedRatio != nil
            || fiveHourUsedRatio != nil
            || fiveHour != nil
            || sessionResetAt != nil
            || currentResetAt != nil
            || resetAt != nil
            || sevenDay != nil
    }

    var resetDate: Date? {
        [sessionResetAt, currentResetAt, resetAt, fiveHour?.resetsAt]
            .compactMap { $0 }
            .compactMap(KnownUsagePayload.parseDate)
            .first
    }

    var weeklyUsedRatio: Double? {
        sevenDay?.utilization.map { min(max($0 / 100, 0), 1) }
    }

    var weeklyResetDate: Date? {
        guard let value = sevenDay?.resetsAt else { return nil }
        return KnownUsagePayload.parseDate(value)
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private struct KnownFiveHourUsage: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private struct KnownSevenDayUsage: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private struct KnownOrganizationEnvelope: Decodable {
    let organizationID: String?
    let activeOrganizationID: String?
    let selectedOrganizationID: String?
    let organizations: [KnownOrganization]?
    let data: [KnownOrganization]?

    enum CodingKeys: String, CodingKey {
        case organizationID = "organization_id"
        case activeOrganizationID = "active_organization_id"
        case selectedOrganizationID = "selected_organization_id"
        case organizations
        case data
    }

    var detectedOrganizationID: String? {
        organizationID
            ?? activeOrganizationID
            ?? selectedOrganizationID
            ?? organizations?.first?.id
            ?? data?.first?.id
    }
}

private struct KnownOrganization: Decodable {
    let id: String
}

struct UsageResponse {
    let snapshot: UsageSnapshot
    let organizationID: String
    let rawPayload: Data
}

enum FetchError: LocalizedError, Equatable {
    case invalidResponse
    case authRequired
    case rateLimited
    case missingOrganizationID
    case organizationNotFound
    case timeout
    case networkUnavailable
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: L10n.tr("fetch_error.invalid_response")
        case .authRequired: L10n.tr("fetch_error.auth_required")
        case .rateLimited: L10n.tr("fetch_error.rate_limited")
        case .missingOrganizationID: L10n.tr("fetch_error.missing_organization_id")
        case .organizationNotFound: L10n.tr("fetch_error.organization_not_found")
        case .timeout: L10n.tr("fetch_error.timeout")
        case .networkUnavailable: L10n.tr("fetch_error.network_unavailable")
        case .serverError(let code): L10n.tr("fetch_error.server_error", code)
        }
    }
}

private struct UsagePayload {
    let root: Any

    init(data: Data) throws {
        root = try JSONSerialization.jsonObject(with: data)
    }

    var usedRatioValue: Double {
        if let ratio = bestNumber(forKeys: [
            "session_used_ratio",
            "sessionUsedRatio",
            "current_session_used_ratio",
            "currentSessionUsedRatio",
            "current_window_used_ratio",
            "currentWindowUsedRatio",
            "five_hour_used_ratio",
            "fiveHourUsedRatio",
            "used_ratio",
            "usedRatio",
            "usage_ratio",
            "usageRatio",
            "ratio",
        ]) {
            return normalizedRatio(ratio)
        }

        if let percent = bestNumber(forKeys: [
            "session_percent_used",
            "sessionPercentUsed",
            "current_session_percent_used",
            "currentSessionPercentUsed",
            "current_window_percent_used",
            "currentWindowPercentUsed",
            "five_hour_utilization",
            "fiveHourUtilization",
            "utilization",
            "percent_used",
            "percentUsed",
            "usage_percent",
            "usagePercent",
            "usage_percentage",
            "usagePercentage",
        ]) {
            return normalizedPercent(percent)
        }

        let usedMatches = collectValues(forKeys: [
            "session_used",
            "sessionUsed",
            "current_session_used",
            "currentSessionUsed",
            "window_used",
            "windowUsed",
            "current_window_used",
            "currentWindowUsed",
            "used",
            "consumed",
            "current_usage",
            "currentUsage",
            "used_messages",
            "usedMessages",
            "messages_used",
            "messagesUsed",
            "message_count",
            "messageCount",
            "num_messages_used",
            "numMessagesUsed",
        ])

        let limitMatches = collectValues(forKeys: [
            "session_limit",
            "sessionLimit",
            "current_session_limit",
            "currentSessionLimit",
            "window_limit",
            "windowLimit",
            "current_window_limit",
            "currentWindowLimit",
            "limit",
            "max",
            "quota",
            "message_limit",
            "messageLimit",
            "max_messages",
            "maxMessages",
            "total",
        ])

        let remainingMatches = collectValues(forKeys: [
            "session_remaining",
            "sessionRemaining",
            "current_session_remaining",
            "currentSessionRemaining",
            "window_remaining",
            "windowRemaining",
            "current_window_remaining",
            "currentWindowRemaining",
            "remaining",
            "remaining_messages",
            "remainingMessages",
            "available",
            "available_messages",
            "availableMessages",
            "left",
        ])

        if let pairedRatio = bestRatioFromPairedValues(primary: usedMatches, secondary: limitMatches, subtractFromOne: false) {
            return pairedRatio
        }

        if let pairedRatio = bestRatioFromPairedValues(primary: remainingMatches, secondary: limitMatches, subtractFromOne: true) {
            return pairedRatio
        }

        let used = bestNumber(from: usedMatches)
        let limit = bestNumber(from: limitMatches)
        let remaining = bestNumber(from: remainingMatches)

        if let used, let limit, limit > 0 {
            return clamped(used / limit)
        }

        if let remaining, let limit, limit > 0 {
            return clamped(1 - (remaining / limit))
        }

        if let used, let remaining, used + remaining > 0 {
            return clamped(used / (used + remaining))
        }

        if let used {
            return normalizedRatio(used)
        }

        return 0
    }

    var resetDate: Date? {
        let timestampKeys = [
            "session_reset_at_timestamp",
            "sessionResetAtTimestamp",
            "current_reset_at_timestamp",
            "currentResetAtTimestamp",
            "window_reset_at_timestamp",
            "windowResetAtTimestamp",
            "next_message_reset_at_timestamp",
            "nextMessageResetAtTimestamp",
            "reset_at_timestamp",
            "resetAtTimestamp",
            "resets_at_timestamp",
            "resetsAtTimestamp",
            "next_reset_at_timestamp",
            "nextResetAtTimestamp",
        ]

        let stringKeys = [
            "session_reset_at",
            "sessionResetAt",
            "current_reset_at",
            "currentResetAt",
            "window_reset_at",
            "windowResetAt",
            "next_message_reset_at",
            "nextMessageResetAt",
            "reset_at",
            "resetAt",
            "resets_at",
            "resetsAt",
            "next_reset_at",
            "nextResetAt",
            "reset_time",
            "resetTime",
        ]

        let timestampCandidates = collectValues(forKeys: timestampKeys)
            .compactMap { candidate -> WeightedDateCandidate? in
                guard let number = number(from: candidate.value) else { return nil }
                return WeightedDateCandidate(
                    date: dateFromTimestamp(number),
                    score: scoreForResetCandidate(key: candidate.key, path: candidate.path)
                )
            }

        let stringCandidates = collectValues(forKeys: stringKeys)
            .compactMap { candidate -> WeightedDateCandidate? in
                guard let string = candidate.value as? String,
                      let date = parseDate(string) else { return nil }
                return WeightedDateCandidate(
                    date: date,
                    score: scoreForResetCandidate(key: candidate.key, path: candidate.path)
                )
            }

        let candidates = timestampCandidates + stringCandidates
        let now = Date()
        let futureCandidates = candidates.filter { $0.date > now.addingTimeInterval(-60) }

        if let preferred = futureCandidates.max(by: compareWeightedDates) {
            return preferred.date
        }

        return candidates.max(by: compareWeightedDates)?.date
    }

    var weeklyUsedRatio: Double? {
        if let utilization = number(inTopLevelBucket: "seven_day", key: "utilization") {
            return normalizedPercent(utilization)
        }
        return nil
    }

    var weeklyResetDate: Date? {
        if let timestamp = number(inTopLevelBucket: "seven_day", key: "resets_at_timestamp") {
            return dateFromTimestamp(timestamp)
        }

        if let value = string(inTopLevelBucket: "seven_day", key: "resets_at") {
            return parseDate(value)
        }

        return nil
    }

    private func normalizedRatio(_ value: Double) -> Double {
        if value > 1, value <= 100 {
            return normalizedPercent(value)
        }
        return clamped(value)
    }

    private func normalizedPercent(_ value: Double) -> Double {
        clamped(value / 100)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func dateFromTimestamp(_ value: Double) -> Date {
        if value > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }

    private func parseDate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = isoFormatter.date(from: value) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }

    private func bestNumber(forKeys keys: [String]) -> Double? {
        bestNumber(from: collectValues(forKeys: keys))
    }

    private func bestNumber(from values: [MatchedValue]) -> Double? {
        let candidates = values.compactMap { candidate -> WeightedNumberCandidate? in
            guard let number = number(from: candidate.value) else { return nil }
            return WeightedNumberCandidate(
                value: number,
                score: scoreForUsageCandidate(key: candidate.key, path: candidate.path),
                path: candidate.path
            )
        }

        return candidates.max(by: compareWeightedNumbers)?.value
    }

    private func bestRatioFromPairedValues(primary: [MatchedValue], secondary: [MatchedValue], subtractFromOne: Bool) -> Double? {
        let primaryCandidates = primary.compactMap { candidate -> WeightedNumberCandidate? in
            guard let number = number(from: candidate.value) else { return nil }
            return WeightedNumberCandidate(
                value: number,
                score: scoreForUsageCandidate(key: candidate.key, path: candidate.path),
                path: candidate.path
            )
        }

        let secondaryCandidates = secondary.compactMap { candidate -> WeightedNumberCandidate? in
            guard let number = number(from: candidate.value), number > 0 else { return nil }
            return WeightedNumberCandidate(
                value: number,
                score: scoreForUsageCandidate(key: candidate.key, path: candidate.path),
                path: candidate.path
            )
        }

        var bestRatio: Double?
        var bestScore = Int.min

        for lhs in primaryCandidates {
            for rhs in secondaryCandidates {
                let rawRatio = lhs.value / rhs.value
                guard rawRatio >= 0, rawRatio <= 1.2 else { continue }

                let score = lhs.score + rhs.score + sharedPathScore(lhs.path, rhs.path)
                let ratio = subtractFromOne ? clamped(1 - rawRatio) : clamped(rawRatio)

                if score > bestScore {
                    bestScore = score
                    bestRatio = ratio
                }
            }
        }

        return bestRatio
    }

    private func collectValues(forKeys keys: [String]) -> [MatchedValue] {
        var matches: [MatchedValue] = []
        for key in keys {
            matches.append(contentsOf: findValues(forKey: key, in: root, path: []))
        }
        return matches
    }

    private func findValues(forKey key: String, in value: Any, path: [String]) -> [MatchedValue] {
        var matches: [MatchedValue] = []

        if let dictionary = value as? [String: Any] {
            for (candidateKey, nestedValue) in dictionary {
                if candidateKey == key {
                    matches.append(MatchedValue(key: candidateKey, value: nestedValue, path: path + [candidateKey]))
                }
                matches.append(contentsOf: findValues(forKey: key, in: nestedValue, path: path + [candidateKey]))
            }
        } else if let array = value as? [Any] {
            for (index, item) in array.enumerated() {
                matches.append(contentsOf: findValues(forKey: key, in: item, path: path + ["[\(index)]"]))
            }
        }

        return matches
    }

    private func number(from value: Any) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func number(inTopLevelBucket bucket: String, key: String) -> Double? {
        guard let dictionary = root as? [String: Any],
              let nested = dictionary[bucket] as? [String: Any],
              let value = nested[key] else {
            return nil
        }

        return number(from: value)
    }

    private func string(inTopLevelBucket bucket: String, key: String) -> String? {
        guard let dictionary = root as? [String: Any],
              let nested = dictionary[bucket] as? [String: Any],
              let value = nested[key] as? String,
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private func scoreForUsageCandidate(key: String, path: [String]) -> Int {
        let tokens = ([key] + path).map { $0.lowercased() }
        var score = 0

        for token in tokens {
            if token.contains("session") || token.contains("current") || token.contains("window") || token.contains("message") {
                score += 5
            }
            if token.contains("five_hour") || token.contains("fivehour") || token.contains("5h") {
                score += 10
            }
            if token.contains("active") || token.contains("chat") {
                score += 2
            }
            if token.contains("daily") || token.contains("day") {
                score += 1
            }
            if token.contains("week") || token.contains("weekly") || token.contains("month") || token.contains("monthly") {
                score -= 6
            }
            if token.contains("account") || token.contains("workspace") {
                score -= 1
            }
        }

        if key.lowercased().contains("ratio") || key.lowercased().contains("percent") {
            score += 1
        }

        return score
    }

    private func scoreForResetCandidate(key: String, path: [String]) -> Int {
        let tokens = ([key] + path).map { $0.lowercased() }
        var score = 0

        for token in tokens {
            if token.contains("session") || token.contains("current") || token.contains("window") || token.contains("message") {
                score += 8
            }
            if token.contains("five_hour") || token.contains("fivehour") || token.contains("5h") {
                score += 12
            }
            if token.contains("active") || token.contains("chat") {
                score += 3
            }
            if token.contains("next") {
                score += 1
            }
            if token.contains("week") || token.contains("weekly") || token.contains("month") || token.contains("monthly") {
                score -= 8
            }
        }

        return score
    }

    private func compareWeightedNumbers(_ lhs: WeightedNumberCandidate, _ rhs: WeightedNumberCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        return lhs.path.count < rhs.path.count
    }

    private func compareWeightedDates(_ lhs: WeightedDateCandidate, _ rhs: WeightedDateCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }

        let lhsDelta = abs(lhs.date.timeIntervalSinceNow)
        let rhsDelta = abs(rhs.date.timeIntervalSinceNow)
        return lhsDelta > rhsDelta
    }

    private func sharedPathScore(_ lhs: [String], _ rhs: [String]) -> Int {
        var score = 0

        for (left, right) in zip(lhs, rhs) {
            if left == right {
                score += 4
            } else {
                break
            }
        }

        return score
    }
}

private struct MatchedValue {
    let key: String
    let value: Any
    let path: [String]
}

private struct WeightedNumberCandidate {
    let value: Double
    let score: Int
    let path: [String]
}

private struct WeightedDateCandidate {
    let date: Date
    let score: Int
}
