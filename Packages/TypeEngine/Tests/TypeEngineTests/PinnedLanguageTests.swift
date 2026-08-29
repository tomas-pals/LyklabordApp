import XCTest

@testable import TypeEngine

/// `EngineConfig.pinnedLanguage` — hard IS/EN separation. The keyboard's
/// language key selects one lexicon and NOTHING from the other may leak into
/// suggestions, predictions, validity or scoring.
final class PinnedLanguageTests: XCTestCase {

    private func engine(_ pinned: EngineConfig.PinnedLanguage?) -> TypeEngine {
        var config = EngineConfig()
        config.pinnedLanguage = pinned
        return Fixtures.engine(morphology: FakeMorphology(["bíllinn"]), config: config)
    }

    private func session(_ pinned: EngineConfig.PinnedLanguage?) -> TypingSession {
        TypingSession(engine: engine(pinned))
    }

    private func bar(_ session: TypingSession, _ text: String) -> [String] {
        var buffer = ""
        var result: [Suggestion] = []
        for ch in text {
            buffer.append(ch)
            result = session.suggestions(for: buffer, limit: 4)
        }
        return result.filter { !$0.isVerbatim }.map(\.text)
    }

    // MARK: - Suggestions do not cross the language boundary

    func testIcelandicModeNeverSuggestsEnglishWords() {
        // "th" completes to "the" in the blended engine; the English lexicon
        // is not consulted at all in Icelandic mode.
        XCTAssertTrue(bar(session(nil), "th").contains("the"))
        XCTAssertFalse(bar(session(.icelandic), "th").contains("the"))
    }

    func testEnglishModeNeverSuggestsIcelandicWords() {
        XCTAssertTrue(bar(session(nil), "hest").contains("hestur"))
        XCTAssertEqual(bar(session(.english), "hest"), [])
    }

    func testPredictionsAreDrawnFromTheActiveLexiconOnly() {
        let icelandic = session(.icelandic)
        icelandic.suggestions(for: "góðan ")
        XCTAssertTrue(icelandic.suggestions(for: "góðan ").allSatisfy {
            Fixtures.icelandic.frequency(of: $0.text) != nil
        })

        let english = session(.english)
        XCTAssertTrue(english.suggestions(for: "with ").allSatisfy {
            Fixtures.english.frequency(of: $0.text) != nil
        })
    }

    // MARK: - Validity

    func testWordValidityIsScopedToTheActiveLanguage() {
        XCTAssertTrue(engine(nil).isValidTypedWord("hestur"))
        XCTAssertTrue(engine(nil).isValidTypedWord("the"))

        XCTAssertTrue(engine(.icelandic).isValidTypedWord("hestur"))
        XCTAssertFalse(engine(.icelandic).isValidTypedWord("the"))

        XCTAssertFalse(engine(.english).isValidTypedWord("hestur"))
        XCTAssertTrue(engine(.english).isValidTypedWord("the"))
    }

    func testBinMorphologyIsOffInEnglishMode() {
        // BÍN validates 3M Icelandic forms; consulting it in English mode
        // would readmit the whole Icelandic vocabulary through the back door.
        XCTAssertTrue(engine(.icelandic).isValidTypedWord("bíllinn"))
        XCTAssertFalse(engine(.english).isValidTypedWord("bíllinn"))
    }

    // MARK: - Lane posterior

    func testPinnedPosteriorIsSaturatedAndImmovable() {
        let icelandic = engine(.icelandic)
        XCTAssertEqual(icelandic.probabilityIcelandic, icelandic.config.posteriorCeiling)
        for word in ["the", "and", "with", "the", "and"] { icelandic.confirmWord(word) }
        icelandic.noteSentenceBoundary()
        XCTAssertEqual(
            icelandic.probabilityIcelandic, icelandic.config.posteriorCeiling,
            "English commits must not drag a pinned Icelandic lane")

        let english = engine(.english)
        XCTAssertEqual(english.probabilityIcelandic, english.config.posteriorFloor)
        for word in ["og", "að", "ekki"] { english.confirmWord(word) }
        XCTAssertEqual(english.probabilityIcelandic, english.config.posteriorFloor)
    }

    func testResetReturnsToThePinnedPosteriorNotNeutral() {
        let e = engine(.icelandic)
        e.resetLanguagePosterior()
        XCTAssertEqual(e.probabilityIcelandic, e.config.posteriorCeiling)

        let blended = engine(nil)
        blended.resetLanguagePosterior()
        XCTAssertEqual(blended.probabilityIcelandic, 0.5)
    }

    // MARK: - Corrections stay in-language

    func testCorrectionTargetsComeFromTheActiveLanguageOnly() {
        // "greep" sits between the fixture's twins "greeþ" (IS) and "green"
        // (EN). Whichever mode is on decides which one space commits.
        let icelandic = bar(session(.icelandic), "greep")
        XCTAssertTrue(icelandic.contains("greeþ"))
        XCTAssertFalse(icelandic.contains("green"))

        let english = bar(session(.english), "greep")
        XCTAssertTrue(english.contains("green"))
        XCTAssertFalse(english.contains("greeþ"))
    }
}
