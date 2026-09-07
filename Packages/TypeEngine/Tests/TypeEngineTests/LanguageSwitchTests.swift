import XCTest

@testable import TypeEngine

/// Wrong-language detection while pinned: the token is attested only in
/// the other lexicon (or carries exclusive Icelandic letters).
final class LanguageSwitchTests: XCTestCase {

    private func engine(_ pinned: EngineConfig.PinnedLanguage) -> TypeEngine {
        var config = EngineConfig()
        config.pinnedLanguage = pinned
        return Fixtures.engine(config: config)
    }

    func testEnglishOnlyWordInIcelandicModeSuggestsEnglish() {
        XCTAssertEqual(engine(.icelandic).suggestedLanguageSwitch(for: "hello"), .english)
        XCTAssertEqual(engine(.icelandic).suggestedLanguageSwitch(for: "the"), .english)
    }

    func testIcelandicOnlyWordInEnglishModeSuggestsIcelandic() {
        XCTAssertEqual(engine(.english).suggestedLanguageSwitch(for: "hestur"), .icelandic)
        XCTAssertEqual(engine(.english).suggestedLanguageSwitch(for: "ekki"), .icelandic)
    }

    func testAttestedInActiveLanguageDoesNotSuggestASwitch() {
        XCTAssertNil(engine(.icelandic).suggestedLanguageSwitch(for: "hestur"))
        XCTAssertNil(engine(.english).suggestedLanguageSwitch(for: "hello"))
    }

    func testShortTokensAreIgnored() {
        XCTAssertNil(engine(.icelandic).suggestedLanguageSwitch(for: "th"))
        XCTAssertNil(engine(.english).suggestedLanguageSwitch(for: "he"))
    }

    func testExclusiveIcelandicLettersFlipEnglishMode() {
        XCTAssertEqual(engine(.english).suggestedLanguageSwitch(for: "greeþ"), .icelandic)
        XCTAssertEqual(engine(.english).suggestedLanguageSwitch(for: "þetta"), .icelandic)
    }

    func testUnpinnedEngineNeverSuggestsASwitch() {
        XCTAssertNil(Fixtures.engine().suggestedLanguageSwitch(for: "hello"))
        XCTAssertNil(Fixtures.engine().suggestedLanguageSwitch(for: "hestur"))
    }
}
