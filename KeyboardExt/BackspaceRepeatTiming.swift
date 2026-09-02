//
//  BackspaceRepeatTiming.swift
//  LyklabordKeyboard
//
//  Long-press backspace deletes whole words. The pause between
//  words starts short, shrinks over a fixed ramp, and floors at
//  a minimum so a held delete never becomes a blur.
//

import Foundation

enum BackspaceRepeatTiming {

    /// Pause before the second word (first word fires immediately
    /// when the repeat timer starts, after GestureButton's 0.5s
    /// repeatDelay).
    static let startPause: TimeInterval = 0.32

    /// Fastest word-delete cadence.
    static let minPause: TimeInterval = 0.09

    /// Hold time, after repeat starts, to reach ``minPause``.
    static let ramp: TimeInterval = 1.6

    /// Pause after `duration` seconds of word-delete repeat.
    static func pause(afterHold duration: TimeInterval) -> TimeInterval {
        guard duration < ramp else { return minPause }
        guard duration > 0 else { return startPause }
        return startPause * pow(minPause / startPause, duration / ramp)
    }
}
