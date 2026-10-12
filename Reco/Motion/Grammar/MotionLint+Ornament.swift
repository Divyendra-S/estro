//
//  MotionLint+Ornament.swift
//  Reco
//

import Foundation

/// A decoration repeated through a film (spec 0026).
nonisolated extension MotionLint {

    /// A line of one colour drawn on its own (a shape not in a group, its thinner side at most ``thinnest`` of the canvas's
    /// shorter side, at its size or a morph's) in ``mostLines`` scenes or more. Mastra 4 drew a green line under its code, its
    /// tab, its statement, its score and its logo, and the user saw "a green line which was everywhere … repeating itself".
    static func ornamentFindings(_ document: MotionDocument) -> [Finding] {
        let shorter = min(document.canvas.size.width, document.canvas.size.height)
        let isLine = { (size: CGSize) in
            min(size.width, size.height) <= thinnest * shorter && max(size.width, size.height) >= 8 * min(size.width, size.height)
        }
        var scenes: [String: [String]] = [:]
        for scene in document.scenes {
            let colors = Set(scene.layers.compactMap { layer -> String? in
                guard case .shape(let shape) = layer.content, shape.kind == .rectangle,
                      isLine(shape.size) || layer.moves.contains(where: { $0.kind == .morph && $0.size.map(isLine) == true }) else { return nil }
                let channel = { (value: Double) in String(Int((value * 20).rounded())) }
                return [shape.color.red, shape.color.green, shape.color.blue].map(channel).joined(separator: ",")
            })
            for color in colors {
                scenes[color, default: []].append(scene.id)
            }
        }
        return scenes.values.filter { $0.count >= mostLines }.sorted { $0.count > $1.count }.map { ids in
            let message = "One line is drawn in scenes \(ids.map { "\"\($0)\"" }.joined(separator: ", ")): a decoration repeated through the film "
                + "reads as a template. Underline and rule nothing the site doesn't; change the product's own things instead."
            return Finding(rule: .ornament, scene: ids[0], message: message)
        }
    }

    /// A line is at most 1.2 % of the canvas's shorter side thick (13 px at 1080p; Mastra 4's were 6–12); three scenes of one is
    /// a motif.
    static let thinnest = 0.012
    static let mostLines = 3
}
