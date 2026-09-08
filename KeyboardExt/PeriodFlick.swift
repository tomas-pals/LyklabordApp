//
//  PeriodFlick.swift
//  LyklabordKeyboard
//
//  Quick horizontal swipe on the bottom-row period key. Long-press still
//  opens the punctuation callout; a flick should not require landing on a
//  specific callout slot.
//
//      swipe left  →  ,
//      swipe right →  ?
//

import Foundation

enum PeriodFlick: Equatable {
    case comma
    case questionMark

    /// Horizontal movement that commits a flick, in points. The period key
    /// is ~8% of the row (~30pt); this is a short swipe, not a precise pick.
    static let threshold: Double = 20

    var character: String {
        switch self {
        case .comma: ","
        case .questionMark: "?"
        }
    }

    /// Classify a drag delta. Nil when the motion is too small or mostly vertical.
    static func resolve(dx: Double, dy: Double) -> PeriodFlick? {
        guard abs(dx) >= threshold, abs(dx) > abs(dy) else { return nil }
        return dx < 0 ? .comma : .questionMark
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

extension PeriodFlick {
    static func resolve(from start: CGPoint, to current: CGPoint) -> PeriodFlick? {
        resolve(dx: Double(current.x - start.x), dy: Double(current.y - start.y))
    }
}
#endif
