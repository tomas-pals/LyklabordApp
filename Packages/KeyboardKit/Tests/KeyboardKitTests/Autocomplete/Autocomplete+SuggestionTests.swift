//
//  Autocomplete+SuggestionTests.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2024-10-13.
//  Copyright © 2024-2025 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import XCTest

final class Autocomplete_SuggestionTests: XCTestCase {

    func testCanDetectType() {
        let autocorrect = Autocomplete.Suggestion(text: "foo", type: .autocorrect)
        let regular = Autocomplete.Suggestion(text: "foo", type: .regular)
        let unknown = Autocomplete.Suggestion(text: "foo", type: .unknown)
        let suggestions = [autocorrect, regular, unknown]
        suggestions.forEach { suggestion in
            XCTAssertEqual(suggestion.isAutocorrect, suggestion.type == .autocorrect)
            XCTAssertEqual(suggestion.isRegular, suggestion.type == .regular)
            XCTAssertEqual(suggestion.isUnknown, suggestion.type == .unknown)
        }
    }

    func testHidableFromDictionaryIncludesUnknownCommitSlot() {
        XCTAssertTrue(
            Autocomplete.Suggestion(text: "hello", type: .unknown).isHidableFromDictionary,
            "centre commit is often .unknown once a character is typed"
        )
        XCTAssertTrue(Autocomplete.Suggestion(text: "hello", type: .regular).isHidableFromDictionary)
        XCTAssertTrue(Autocomplete.Suggestion(text: "hello", type: .autocorrect).isHidableFromDictionary)
        XCTAssertFalse(Autocomplete.Suggestion(text: "😊", type: .emoji).isHidableFromDictionary)
        XCTAssertFalse(Autocomplete.Suggestion(text: "", type: .regular).isHidableFromDictionary)
    }

    func testCanApplyAutocompleteCasing() {
        let suggestion = Autocomplete.Suggestion(text: "foo")
        XCTAssertEqual(suggestion.autocompleteCased(for: "word").text, "foo")
        XCTAssertEqual(suggestion.autocompleteCased(for: "Word").text, "foo")
        XCTAssertEqual(suggestion.autocompleteCased(for: "WORD").text, "FOO")
    }
}
