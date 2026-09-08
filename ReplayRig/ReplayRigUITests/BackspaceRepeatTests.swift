//
//  BackspaceRepeatTests.swift
//  ReplayRigUITests
//
//  Long-press backspace: whole words, pauses shrink to a floor.
//  BackspaceRepeatTiming / LyklabordKeyboardBehavior are compiled
//  into this bundle (KeyboardExt has no unit-test target).
//

import KeyboardKit
import XCTest

final class BackspaceRepeatTests: XCTestCase {

    func testPauseStartsAtTheShortDelay() {
        XCTAssertEqual(
            BackspaceRepeatTiming.pause(afterHold: 0),
            BackspaceRepeatTiming.startPause
        )
    }

    func testPauseShrinksWhileHolding() {
        let early = BackspaceRepeatTiming.pause(afterHold: 0.3)
        let mid = BackspaceRepeatTiming.pause(afterHold: 0.8)
        let late = BackspaceRepeatTiming.pause(afterHold: 1.3)
        XCTAssertGreaterThan(BackspaceRepeatTiming.startPause, early)
        XCTAssertGreaterThan(early, mid)
        XCTAssertGreaterThan(mid, late)
        XCTAssertGreaterThan(late, BackspaceRepeatTiming.minPause)
    }

    func testPauseFloorsAtTheMinimum() {
        XCTAssertEqual(
            BackspaceRepeatTiming.pause(afterHold: BackspaceRepeatTiming.ramp),
            BackspaceRepeatTiming.minPause
        )
        XCTAssertEqual(
            BackspaceRepeatTiming.pause(afterHold: BackspaceRepeatTiming.ramp + 4),
            BackspaceRepeatTiming.minPause
        )
    }

    func testTapDeletesACharacterAndHoldDeletesWords() {
        let timer = GestureButtonTimer()
        let behavior = LyklabordKeyboardBehavior(
            keyboardContext: KeyboardContext(),
            repeatGestureTimer: timer
        )
        XCTAssertEqual(behavior.backspaceRange, .character)
        timer.start {}
        XCTAssertEqual(behavior.backspaceRange, .word)
        timer.stop()
        XCTAssertEqual(behavior.backspaceRange, .character)
    }

    func testSharedTimerFiresImmediatelyThenAccelerates() {
        let timer = GestureButtonTimer()
        _ = LyklabordKeyboardBehavior(
            keyboardContext: KeyboardContext(),
            repeatGestureTimer: timer
        )
        XCTAssertTrue(timer.fireImmediately)
        XCTAssertEqual(
            timer.nextInterval(after: 0),
            BackspaceRepeatTiming.startPause
        )
        XCTAssertEqual(
            timer.nextInterval(after: BackspaceRepeatTiming.ramp),
            BackspaceRepeatTiming.minPause
        )
        XCTAssertLessThan(
            timer.nextInterval(after: 0.7),
            timer.nextInterval(after: 0.2)
        )
    }
}
