import XCTest
@testable import Learning

final class HiddenSuggestionsStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: HiddenSuggestionsStore!

    override func setUpWithError() throws {
        suiteName = "HiddenSuggestionsStoreTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = HiddenSuggestionsStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testHideThenListThenUnhide() {
        store.hide("hestur", language: .icelandic)
        store.hide("the", language: .english)
        XCTAssertEqual(store.words(for: .icelandic), ["hestur"])
        XCTAssertEqual(store.words(for: .english), ["the"])
        XCTAssertTrue(store.isHidden("Hestur", language: .icelandic))
        XCTAssertFalse(store.isHidden("hestur", language: .english))

        store.unhide("HESTUR", language: .icelandic)
        XCTAssertEqual(store.words(for: .icelandic), [])
        XCTAssertEqual(store.words(for: .english), ["the"])
    }

    func testHideIsCaseInsensitiveDeduped() {
        store.hide("The", language: .english)
        store.hide("the", language: .english)
        store.hide("THE", language: .english)
        XCTAssertEqual(store.words(for: .english), ["The"])
    }

    func testEmptyAndWhitespaceAreNoOps() {
        store.hide("   ", language: .icelandic)
        store.hide("", language: .icelandic)
        XCTAssertEqual(store.words(for: .icelandic), [])
    }

    func testClearAllWipesBothLanguages() {
        store.hide("og", language: .icelandic)
        store.hide("and", language: .english)
        store.clearAll()
        XCTAssertEqual(store.words(for: .icelandic), [])
        XCTAssertEqual(store.words(for: .english), [])
    }

    func testHiddenSetIsLowercased() {
        store.hide("Miðeind", language: .icelandic)
        XCTAssertEqual(store.hiddenSet(for: .icelandic), ["miðeind"])
    }
}
