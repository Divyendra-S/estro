//
//  MoveExpansion+States.swift
//  Reco
//

import Foundation

/// UI changing state as the thing itself, not a swap (spec 0025): a label turning into the next letter by letter, a list
/// spinning on a drum to its choice. Measured on four launch clips (`~/Movies/Reco/references/x-four/`, 30 fps).
nonisolated extension MoveExpansion {

    /// "Create Agent" (12 letters) came in 0.45 s; "Eleven Creative" (15) went in 0.23 s, the new letters starting 0.12 s in.
    static let decodeDuration = 0.45
    static let dissolveDuration = 0.25
    static let retextDuration = 0.57
    static let retextLag = 0.12

    /// A product menu spun four rows in 0.55 s on the move curve, blurred through its middle.
    static func wheelDuration(rows: Double) -> Double {
        min(0.35 + 0.05 * abs(rows), 0.9)
    }

    static func stateDuration(of move: MotionMove) -> Double {
        switch move.kind {
        case .decode: decodeDuration
        case .dissolve: dissolveDuration
        case .wheel: wheelDuration(rows: move.intensity ?? 1)
        default: retextDuration
        }
    }

    /// A decode's or dissolve's characters out of order (``TextReveal/scrambled(_:stagger:)``).
    static func scrambledReveal(of move: MotionMove, start: Double, duration: Double, in context: MoveContext) -> TextReveal {
        let decode = move.kind == .decode
        let count = max(context.characters, 1)
        let part = min(decode ? TextReveal.decodePart : TextReveal.dissolvePart, duration)
        let stagger = (duration - part) / (Double(count - 1) + TextReveal.scrambleReach)
        return TextReveal(
            style: decode ? .decode : .dissolve, start: start, stagger: stagger, partDuration: part, offsets: TextReveal.scrambled(count, stagger: stagger)
        )
    }
}
