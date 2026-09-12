//
//  PeriodFlickTests.swift
//  ReplayRigUITests
//
//  Period key flicks: left = comma, right = ?, up = !.
//  PeriodFlick.swift is compiled into this bundle (KeyboardExt has no
//  unit-test target).
//

import XCTest

final class PeriodFlickTests: XCTestCase {

    func testLeftSwipeIsComma() {
        let flick = PeriodFlick.resolve(dx: -30, dy: 2)
        XCTAssertEqual(flick, .comma)
        XCTAssertEqual(flick?.character, ",")
    }

    func testRightSwipeIsQuestionMark() {
        let flick = PeriodFlick.resolve(dx: 30, dy: -2)
        XCTAssertEqual(flick, .questionMark)
        XCTAssertEqual(flick?.character, "?")
    }

    func testUpSwipeIsExclamationMark() {
        let flick = PeriodFlick.resolve(dx: 2, dy: -30)
        XCTAssertEqual(flick, .exclamationMark)
        XCTAssertEqual(flick?.character, "!")
    }

    func testShortOrDownwardMotionIsIgnored() {
        XCTAssertNil(PeriodFlick.resolve(dx: 8, dy: 0))
        XCTAssertNil(PeriodFlick.resolve(dx: 0, dy: 50))
        XCTAssertNil(PeriodFlick.resolve(dx: 0, dy: -8))
    }
}
