//
//  PeriodFlick.swift
//  LyklabordKeyboard
//
//  Directional flicks on the bottom-row period key. No punctuation
//  callout — the four everyday marks live on this one key:
//
//      tap          →  .
//      swipe left   →  ,
//      swipe right  →  ?
//      swipe up     →  !
//
//  Everything else is on the 123 / #+ = boards.
//

import Foundation

enum PeriodFlick: Equatable {
    case comma
    case questionMark
    case exclamationMark

    /// Movement that commits a flick, in points. The period key is ~8% of
    /// the row (~30pt); this is a short swipe, not a precise pick.
    static let threshold: Double = 20

    var character: String {
        switch self {
        case .comma: ","
        case .questionMark: "?"
        case .exclamationMark: "!"
        }
    }

    /// Classify a drag delta. Nil when the motion is too small, or down.
    static func resolve(dx: Double, dy: Double) -> PeriodFlick? {
        let ax = abs(dx), ay = abs(dy)
        guard max(ax, ay) >= threshold else { return nil }
        if ay > ax {
            return dy < 0 ? .exclamationMark : nil
        }
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
