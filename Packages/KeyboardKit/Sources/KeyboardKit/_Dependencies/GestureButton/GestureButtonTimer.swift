//
//  GestureButtonTimer.swift
//  GestureButton
//
//  Created by Daniel Saidi on 2021-01-28.
//  Copyright © 2021-2025 Daniel Saidi. All rights reserved.
//

import Foundation

/// This internal class can be used to repeat an action when
/// a button is kept pressed.
public class GestureButtonTimer: ObservableObject {

    /// Create a custom gesture button timer.
    ///
    /// - Parameters:
    ///   - interval: The trigger interval, by default `0.1`.
    public init(
        interval: TimeInterval = 0.1
    ) {
        self.interval = interval
    }

    deinit { stop() }

    /// Fixed delay used when ``intervalProvider`` is `nil`.
    public var interval: TimeInterval

    /// When set, each fire delay is `intervalProvider(elapsed)`,
    /// where `elapsed` is seconds since ``start(action:)``.
    /// The timer then self-reschedules instead of repeating
    /// at a fixed interval.
    public var intervalProvider: ((TimeInterval) -> TimeInterval)?

    /// If `true`, ``start(action:)`` invokes the action
    /// immediately, then schedules the next fire.
    public var fireImmediately = false

    private var timer: Timer?

    private var startDate: Date?
}

public extension GestureButtonTimer {

    /// The elapsed time since the timer was started.
    var duration: TimeInterval? {
        guard let date = startDate else { return nil }
        return Date().timeIntervalSince(date)
    }

    /// Whether the timer is active.
    var isActive: Bool { startDate != nil }

    /// Delay before the next fire, given hold duration.
    func nextInterval(after elapsed: TimeInterval) -> TimeInterval {
        intervalProvider?(elapsed) ?? interval
    }

    /// Start the repeat gesture timer with a certain action.
    func start(action: @escaping @Sendable () -> Void) {
        if isActive { return }
        stop()
        startDate = Date()
        if fireImmediately {
            action()
            guard startDate != nil else { return }
        }
        armTimer(action)
    }

    /// Stop the repeat gesture timer.
    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
    }
}

extension GestureButtonTimer {

    func modifyStartDate(to date: Date) {
        startDate = date
    }
}

private extension GestureButtonTimer {

    func armTimer(_ action: @escaping @Sendable () -> Void) {
        let delay = nextInterval(after: duration ?? 0)
        let accelerating = intervalProvider != nil
        timer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: !accelerating
        ) { [weak self] _ in
            action()
            guard let self, accelerating, self.startDate != nil else { return }
            self.armTimer(action)
        }
    }
}
