import XCTest
@testable import ClaudeUsage

final class ClaudeFetcherTests: XCTestCase {
    func testParsesKnownRatioPayloadFixture() throws {
        let data = try fixture(named: "usage-ratio")
        let snapshot = try ClaudeFetcher().parseUsageResponse(data)

        XCTAssertEqual(snapshot.usedRatio, 0.52, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.weeklyUsedRatio), 0.61, accuracy: 0.0001)
        XCTAssertNotNil(snapshot.resetAt)
    }

    func testParsesHeuristicUsedLimitPayloadFixture() throws {
        let data = try fixture(named: "usage-used-limit")
        let snapshot = try ClaudeFetcher().parseUsageResponse(data)

        XCTAssertEqual(snapshot.usedRatio, 0.5, accuracy: 0.0001)
    }

    func testDetectsOrganizationIDFromFixture() throws {
        let data = try fixture(named: "organizations")
        let organizationID = ClaudeFetcher().parseOrganizationID(from: data, sourcePath: "/api/organizations")

        XCTAssertEqual(organizationID, "org_fixture_123")
    }

    private func fixture(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
