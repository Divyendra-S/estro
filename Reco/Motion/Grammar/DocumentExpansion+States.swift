//
//  DocumentExpansion+States.swift
//  Reco
//

import Foundation

/// UI changing state as the thing itself (spec 0025): a text turning into the next, a list spinning on a drum.
nonisolated extension DocumentExpansion {

    /// A wheel's drum, in rows: its radius, how large and bright a row is a row from the front, and how far round a row is
    /// gone. A product menu (`~/Movies/Reco/references/x-four/`) showed two rows each side of its choice, the next ones 70–80 %
    /// of its size at half its brightness, the rows beyond barely there.
    static let wheelRadius = 2.0
    static let wheelSide = 0.8
    static let wheelDim = 0.4
    static let wheelGone = 1.35

    /// The text as a group of its states at its place, its own first, then each retext's words in turn: each leaves letter by
    /// letter (`dissolve`) as the next arrives over it (`decode`), ``MoveExpansion/retextLag`` later, and is there (its opacity,
    /// which the checks read) only from its decode to its dissolve's end. Its reveal goes on its first state, its other moves
    /// stay on the group.
    static func retexted(_ layer: MotionLayer, text: TextContent, in context: MoveContext) -> MotionLayer {
        let turns = layer.moves.filter { $0.kind == .retext }
            .map { (words: $0.words?.first ?? text.text, timing: MoveExpansion.timing(of: $0, in: context)) }
            .sorted { $0.timing.start < $1.timing.start }
        let states = (0...turns.count).map { index in
            var content = text
            var moves: [MotionMove] = []
            var opacity: [Keyframe] = []
            if index == 0 {
                moves = layer.moves.filter { $0.kind.needsText && $0.kind != .retext }
            } else {
                let turn = turns[index - 1]
                let arrives = turn.timing.start + min(MoveExpansion.retextLag, turn.timing.duration / 3)
                content.text = turn.words
                moves.append(MotionMove(.decode, start: arrives, duration: turn.timing.start + turn.timing.duration - arrives))
                opacity += [Keyframe(time: arrives - 1e-3, value: 0, easing: .hold), Keyframe(time: arrives, value: 1)]
            }
            if index < turns.count {
                let turn = turns[index]
                let duration = min(MoveExpansion.dissolveDuration, turn.timing.duration)
                moves.append(MotionMove(.dissolve, start: turn.timing.start, duration: duration))
                opacity += [Keyframe(time: turn.timing.start + duration, value: 1, easing: .hold), Keyframe(time: turn.timing.start + duration + 1e-3, value: 0)]
            }
            var transform = Transform3D()
            transform.anchor = layer.transform.anchor
            var state = MotionLayer(
                id: "\(layer.id).text\(index)", content: .text(content), transform: transform, moves: moves, keyframes: opacity.isEmpty ? [:] : [.opacity: opacity]
            )
            state.shadow = layer.shadow
            return state
        }
        var group = layer
        group.content = .group(states)
        group.moves = layer.moves.filter { !$0.kind.needsText }
        group.shadow = nil
        return group
    }

    /// A wheel's rows on a drum about the group's place: each turned onto it by its distance from the front (``wheelRadius``
    /// rows round), leaning away, smaller and dimmer the farther round, the front one whole and bright. Turned `intensity`
    /// rows (up by default: the rows below come to the front) on the move curve, sampled at 60 Hz as keyframes, so the rows
    /// blur as they pass. The rows' spacing is the middle gap between them.
    static func wheeled(_ rows: [MotionLayer], by wheel: MotionMove, in context: MoveContext) -> [MotionLayer] {
        let places = rows.map(\.transform.position.y).sorted()
        let gaps = zip(places, places.dropFirst()).map { $1 - $0 }.filter { $0 > 1 }.sorted()
        guard !gaps.isEmpty else { return rows }
        let spacing = gaps[gaps.count / 2]
        let timing = MoveExpansion.timing(of: wheel, in: context)
        let travel = (wheel.intensity ?? 1) * spacing * (wheel.direction == .downward ? -1 : 1)
        let count = max(Int((timing.duration * 60).rounded(.up)), 1)
        return rows.map { row in
            var row = row
            var keyframes: [MotionProperty: [Keyframe]] = [:]
            for index in 0...count {
                let fraction = Double(index) / Double(count)
                let turned = travel * MotionEasing.move.progress(fraction, duration: timing.duration)
                let pose = DrumPose(at: row.transform.position.y - turned, spacing: spacing)
                let time = timing.start + fraction * timing.duration
                let values: [(MotionProperty, Double)] = [
                    (.positionY, pose.down), (.positionZ, row.transform.position.z + pose.away), (.rotationX, pose.lean),
                    (.scale, row.transform.scale * pose.scale), (.opacity, row.opacity * pose.opacity)
                ]
                for (property, value) in values {
                    keyframes[property, default: []].append(Keyframe(time: time, value: value))
                }
            }
            row.keyframes.merge(keyframes) { $1 }
            return row
        }
    }

}

/// Where a wheel's row sits on its drum (``DocumentExpansion/wheeled(_:by:in:)``).
nonisolated struct DrumPose {

    /// Its place down and away from the front, its lean (degrees, its top away above the front), its size and opacity.
    let down: Double
    let away: Double
    let lean: Double
    let scale: Double
    let opacity: Double

    /// A row `offset` from the front (canvas pixels, down) on a drum of rows `spacing` apart.
    init(at offset: Double, spacing: Double) {
        let radius = DocumentExpansion.wheelRadius * spacing
        let angle = min(max(offset / radius, -.pi / 2), .pi / 2)
        let near = max(1 - abs(offset) / spacing, 0)
        let front = near * near * (3 - 2 * near)
        let shown = min(max((DocumentExpansion.wheelGone - abs(angle)) / 0.35, 0), 1)
        (down, away, lean) = (radius * sin(angle), radius * (1 - cos(angle)), -angle * 180 / .pi)
        scale = DocumentExpansion.wheelSide + (1 - DocumentExpansion.wheelSide) * front
        opacity = (DocumentExpansion.wheelDim + (1 - DocumentExpansion.wheelDim) * front) * shown
    }
}
