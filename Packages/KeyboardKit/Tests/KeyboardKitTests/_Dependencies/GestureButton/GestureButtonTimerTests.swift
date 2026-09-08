//
//  GestureButtonTimerTests.swift
//  KeyboardKitTests
//

import XCTest
@testable import KeyboardKit

final class GestureButtonTimerTests: XCTestCase {

    func testDefaultIntervalIsUsedWhenNoProviderIsSet() {
        let timer = GestureButtonTimer(interval: 0.1)
        XCTAssertEqual(timer.nextInterval(after: 0), 0.1)
        XCTAssertEqual(timer.nextInterval(after: 2), 0.1)
        XCTAssertFalse(timer.fireImmediately)
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.duration)
    }

    func testIntervalProviderDrivesAcceleratingDelays() {
        let timer = GestureButtonTimer(interval: 0.1)
        timer.intervalProvider = { elapsed in
            max(0.08, 0.32 - elapsed * 0.1)
        }
        XCTAssertEqual(timer.nextInterval(after: 0), 0.32, accuracy: 0.0001)
        XCTAssertEqual(timer.nextInterval(after: 1.2), 0.20, accuracy: 0.0001)
        XCTAssertEqual(timer.nextInterval(after: 10), 0.08, accuracy: 0.0001)
    }

    func testStartMarksTheTimerActiveWithADuration() {
        let timer = GestureButtonTimer()
        timer.start {}
        XCTAssertTrue(timer.isActive)
        XCTAssertNotNil(timer.duration)
        timer.stop()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.duration)
    }
}
