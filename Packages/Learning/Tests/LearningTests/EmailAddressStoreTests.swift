import XCTest

@testable import Learning

final class EmailAddressStoreTests: XCTestCase {

    func testRejectsIncompleteTokens() {
        var store = EmailAddressStore()
        store.record("hello")
        store.record("user@")
        store.record("@host.com")
        store.record("user@host")
        XCTAssertTrue(store.addresses.isEmpty)
    }

    func testRecordsAndDedupesNewestFirst() {
        var store = EmailAddressStore()
        store.record("ada@example.com")
        store.record("bob@example.com")
        store.record("ADA@example.com")
        XCTAssertEqual(store.addresses, ["ADA@example.com", "bob@example.com"])
    }

    func testPrefixSuggestionsPreferRecent() {
        var store = EmailAddressStore()
        store.record("ann@old.com")
        store.record("ada@example.com")
        store.record("bob@example.com")
        XCTAssertEqual(store.suggestions(prefix: "a"), ["ada@example.com", "ann@old.com"])
        XCTAssertEqual(store.suggestions(prefix: "bob@"), ["bob@example.com"])
    }

    func testIngestPullsCompleteEmailsFromAWindow() {
        var store = EmailAddressStore()
        store.ingest(from: "Write ada@example.com please, not hello")
        XCTAssertEqual(store.addresses, ["ada@example.com"])
    }

    func testRoundTripJSON() throws {
        var store = EmailAddressStore()
        store.record("ada@example.com")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("email-store-test.json")
        try store.write(to: url)
        let loaded = EmailAddressStore.load(from: url)
        XCTAssertEqual(loaded.addresses, ["ada@example.com"])
        try? FileManager.default.removeItem(at: url)
    }
}
