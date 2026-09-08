//
//  PeriodFlickTests.swift
//  ReplayRigUITests
//
//  Quick swipe on the period key: left = comma, right = question mark.
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

    func testShortOrVerticalMotionIsIgnored() {
        XCTAssertNil(PeriodFlick.resolve(dx: 8, dy: 0))
        XCTAssertNil(PeriodFlick.resolve(dx: 0, dy: 50))
    }
}
