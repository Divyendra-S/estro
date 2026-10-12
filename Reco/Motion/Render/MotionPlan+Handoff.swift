//
//  MotionPlan+Handoff.swift
//  Reco
//

import CoreGraphics

/// A flow seam's handoff (spec 0020): the scene before's layers leave one after another the way the film goes, the next
/// scene's arrive from the other side over them as they do, and a layer whose id is in both travels from one place to the
/// other (``MotionFrameRenderer/handedOff(into:at:sharpAt:plan:frames:)``). After Effects builds it as offset layers: none
/// moves alone, none waits for the last to finish.
extension MotionPlan {

    /// Each layer leaves over 0.22 s, a tenth of the width along the way, fading; in-cubic, so the scene runs into the cut. The
    /// last starts 0.15 s before the cut and is gone 0.07 s after it, as the next scene's first layers come. Leaving from the
    /// cut, the scene before stood whole under the next's for a fifth of a second; over 0.3 s, unblurred, Mastra 5's trace and
    /// its reply read as two texts on top of each other.
    nonisolated static let flowLeave = (lead: 0.15, duration: 0.22, travel: 0.1)

    /// Each layer arrives from 0.12 of the width back over 0.65 s, out-expo, half there in a fifth of it; seen at once. Neither
    /// blurs (spec 0026): blurred 8–10 px, Mastra 5's code went out under its chat as a smear of two texts.
    nonisolated static let flowArrive = (start: 0.08, duration: 0.65, travel: 0.12, fade: 0.2)

    /// One layer after another, by where it is along the way, the front first: 0.045 s apart, all within 0.15 s. Twelve lines
    /// of code 0.045 s apart would leave over half a second, the last under the next scene.
    nonisolated static let flowStagger = (apart: 0.045, within: 0.15)

    /// How far apart `count` layers flow.
    nonisolated static func flowSpacing(of count: Int) -> Double {
        min(flowStagger.apart, flowStagger.within / Double(max(count - 1, 1)))
    }

    /// A carried layer travels over the seam's first 0.7 s, in-out, its look changing in the middle of it.
    nonisolated static let flowCarry = (duration: 0.7, easing: MotionEasing.cubicBezier(0.65, 0, 0.35, 1))

    /// Which way a flow goes into the scene at `index`: leftwards, then upwards, by turns.
    nonisolated static func flowWay(into index: Int) -> SIMD2<Double> {
        index.isMultiple(of: 2) ? [-1, 0] : [0, -1]
    }

    /// The ids of the drawn layers both scenes have: what a flow carries over.
    nonisolated static func carried(from before: Scene, to next: Scene) -> Set<String> {
        let ids = { (scene: Scene) in Set(scene.layers.filter { $0.isDrawn && !$0.id.isEmpty }.map(\.id)) }
        return ids(before).intersection(ids(next))
    }

    /// The tracks a flow into `next` adds: the scene before's layers leaving from its end, the next's arriving, the carried
    /// ones left to the renderer. A layer filling the canvas is a ground: it stays, or fades in.
    nonisolated static func handOff(from before: inout Scene, to next: inout Scene, way: SIMD2<Double>, canvas: CGSize) {
        let carried = carried(from: before, to: next)
        let leaving = movers(of: before, carrying: carried, way: way, canvas: canvas)
        for (order, index) in leaving.enumerated() {
            let start = before.duration - flowLeave.lead - Double(leaving.count - 1 - order) * flowSpacing(of: leaving.count)
            let (duration, travel) = (flowLeave.duration, flowLeave.travel * canvas.width)
            before.layers[index].moves[.positionX, default: []].append(
                MoveExpansion.ramp(.positionX, (0, way.x * travel), start: start, duration: duration, easing: .exit))
            before.layers[index].moves[.positionY, default: []].append(
                MoveExpansion.ramp(.positionY, (0, way.y * travel), start: start, duration: duration, easing: .exit))
            before.layers[index].moves[.opacity, default: []].append(MoveExpansion.ramp(.opacity, (1, 0), start: start, duration: duration, easing: .exit))
        }
        let arriving = movers(of: next, carrying: carried, way: way, canvas: canvas)
        for (order, index) in arriving.enumerated() {
            let start = flowArrive.start + Double(order) * flowSpacing(of: arriving.count)
            let (duration, travel) = (flowArrive.duration, flowArrive.travel * canvas.width)
            let layer = next.layers[index]
            next.layers[index].moves[.positionX, default: []].append(
                MoveExpansion.ramp(.positionX, (-way.x * travel, 0), start: start, duration: duration, easing: .enterFast))
            next.layers[index].moves[.positionY, default: []].append(
                MoveExpansion.ramp(.positionY, (-way.y * travel, 0), start: start, duration: duration, easing: .enterFast))
            // Unless its own entrance fades it in already
            if layer.value(.opacity, at: 0) > 0.5 {
                next.layers[index].moves[.opacity, default: []].append(
                    MoveExpansion.ramp(.opacity, (0, 1), start: start, duration: flowArrive.fade, easing: .enter))
            }
        }
        // The next scene's ground comes up under what arrives
        for index in next.layers.indices where next.layers[index].parent == nil && isGround(next.layers[index], canvas: canvas) {
            next.layers[index].moves[.opacity, default: []].append(
                MoveExpansion.ramp(.opacity, (0, 1), start: 0, duration: flowArrive.start + flowArrive.fade, easing: .enter))
        }
    }

    /// A scene's top-level layers that flow, front first along `way`: not grounds, and not wholly carried.
    nonisolated private static func movers(of scene: Scene, carrying carried: Set<String>, way: SIMD2<Double>, canvas: CGSize) -> [Int] {
        scene.layers.indices
            .filter { index in
                let layer = scene.layers[index]
                guard layer.parent == nil, !isGround(layer, canvas: canvas) else { return false }
                let drawn = scene.layers.indices.filter { scene.isLayer($0, within: index) && scene.layers[$0].isDrawn }
                return !drawn.allSatisfy { carried.contains(scene.layers[$0].id) }
            }
            .sorted { first, second in
                let along = { (index: Int) in
                    let layer = scene.layers[index]
                    return (layer.base[.positionX] ?? 0) * way.x + (layer.base[.positionY] ?? 0) * way.y
                }
                return (along(first), second) > (along(second), first)
            }
    }

    /// Whether a layer covers the canvas: a scene's ground.
    nonisolated private static func isGround(_ layer: Layer, canvas: CGSize) -> Bool {
        layer.isDrawn && layer.size.width >= canvas.width * 0.95 && layer.size.height >= canvas.height * 0.95
    }
}
