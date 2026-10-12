//
//  MotionLint+Swaps.swift
//  Reco
//

import Foundation

/// Scenes cut inside themselves (spec 0025).
nonisolated extension MotionLint {

    /// A scene whose changes are mostly parts appearing or going at once, each in a place of its own, is cut inside itself:
    /// Mastra 3's files, errors and eval rows came and went that way (61 of its 114 moves), and the user saw "only one or two"
    /// animations in it. A part shown or hidden where another is (a tile's contents on a beat, a picture over the last) is a
    /// swap, and counts as one change.
    static func swapFindings(in scene: MotionScene) -> [Finding] {
        let layers = placed(scene.layers, in: nil)
        let moves = layers.flatMap(\.layer.moves).filter { !$0.kind.isCamera }
        let isCut = { (move: MotionMove) in move.kind == .show || move.kind == .hide }
        let swapping = layers.filter { $0.layer.moves.contains(where: isCut) }
        let alone = swapping.filter { part in
            !swapping.contains { other in
                other.layer.id != part.layer.id && other.parent == part.parent
                    && abs(other.layer.transform.position.x - part.layer.transform.position.x) < 4
                    && abs(other.layer.transform.position.y - part.layer.transform.position.y) < 4
            }
        }
        let cuts = alone.flatMap(\.layer.moves).filter(isCut).count
        guard cuts >= mostCuts, cuts * 2 >= moves.count else { return [] }
        let message = "\(cuts) of the scene's \(moves.count) moves show or hide a part at once in a place of its own, cuts inside it: change the "
            + "things themselves (a label retexts, a status morphs, a list wheels to its choice, files pop or cascade in, an error dissolves)."
        return [Finding(rule: .swaps, scene: scene.id, message: message)]
    }

    private static let mostCuts = 4

    /// Every layer with the id of the group it's placed in.
    private static func placed(_ layers: [MotionLayer], in parent: String?) -> [(layer: MotionLayer, parent: String?)] {
        layers.flatMap { layer -> [(layer: MotionLayer, parent: String?)] in
            guard case .group(let children) = layer.content else { return [(layer, parent)] }
            return [(layer, parent)] + placed(children, in: layer.id)
        }
    }
}
