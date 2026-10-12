//
//  MotionPlan+Pole.swift
//  Reco
//

import CoreImage

/// Where a seam made of a layer goes in (spec 0023): the point farthest inside the layer's shape. A `through` flying into the
/// middle of a word would end in the gap between two letters, into an "o" in its hole, so it flies into where the shape is
/// thickest and ends with that filling the frame.
nonisolated extension MotionPlan {

    nonisolated struct Pole: Equatable, Sendable {
        /// The drawn layer it's in: the seam's layer, or its largest drawn layer when that's a group.
        let layer: Int

        /// From the layer's top-left corner, as shares of its width and height.
        let point: CGPoint

        /// How far it is from the shape's nearest edge, in the layer's canvas pixels.
        let radius: Double
    }

    /// The scenes with the pole of every seam made of a layer, once the layers' images are drawn: in the largest part of the
    /// layer on screen at the cut. A rolling number's words are each a layer, and the first was the largest and long gone.
    func posed() -> [Scene] {
        var scenes = scenes
        for index in scenes.indices.dropFirst() {
            guard let seam = scenes[index].transition?.seam, MotionSeam.madeOfLayer.contains(seam), let layer = scenes[index].opensFrom else { continue }
            let before = scenes[index - 1]
            let shown = placements(of: before, at: before.duration).filter { before.isLayer($0.layer, within: layer) }
            let area = { (placement: Placement) in
                let corners = placement.corners
                return corners.count == 4 ? hypot(corners[1].x - corners[0].x, corners[1].y - corners[0].y) * hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y) : 0
            }
            guard let largest = shown.max(by: { area($0) < area($1) })?.layer else { continue }
            scenes[index].pole = Self.pole(of: before.layers[largest], index: largest)
        }
        return scenes
    }

    /// The pole of `layer`, the scene's layer at `index`: read from its image's coverage at ``poleSamples`` pixels across; the
    /// middle of a layer without an image (a morphing shape, a live take).
    static func pole(of layer: Layer, index: Int) -> Pole {
        let middle = Pole(layer: index, point: CGPoint(x: 0.5, y: 0.5), radius: min(layer.size.width, layer.size.height) / 2)
        guard let image = layer.image, case let extent = image.extent, !extent.isEmpty, !extent.isInfinite else { return middle }
        let scale = poleSamples / max(extent.width, extent.height)
        let (width, height) = (max(Int((extent.width * scale).rounded(.up)), 1), max(Int((extent.height * scale).rounded(.up)), 1))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let small = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY).concatenating(CGAffineTransform(scaleX: scale, y: scale)))
        poleContext.render(small, toBitmap: &bytes, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: nil)
        let inside = (0..<width * height).map { bytes[$0 * 4 + 3] >= 128 }
        guard let deepest = farthestInside(inside, width: width, height: height) else { return middle }
        // A sample's share of the extent, which is the layer's content at its raster scale
        let (column, row) = (deepest.index % width, deepest.index / width)
        let (across, down) = ((Double(column) + 0.5) / scale / extent.width, (Double(row) + 0.5) / scale / extent.height)
        return Pole(layer: index, point: CGPoint(x: across, y: down), radius: deepest.distance / scale * layer.size.width / extent.width)
    }

    /// The cell of `inside` (`width` × `height`, row after row from the top) farthest from any cell outside it or the edge, the
    /// nearest the middle among those as far within half a cell, and its distance in cells; `nil` when nothing is inside.
    static func farthestInside(_ inside: [Bool], width: Int, height: Int) -> (index: Int, distance: Double)? {
        let diagonal = 2.0.squareRoot()
        var distance = inside.map { $0 ? Double(width + height) : 0 }
        let reach = { (distance: [Double], column: Int, row: Int) in
            (0..<width).contains(column) && (0..<height).contains(row) ? distance[row * width + column] : 0
        }
        // Two chamfer passes: from the top left, then from the bottom right
        for (rows, columns, step) in [(Array(0..<height), Array(0..<width), -1), (Array((0..<height).reversed()), Array((0..<width).reversed()), 1)] {
            for row in rows {
                for column in columns where distance[row * width + column] > 0 {
                    let near = min(reach(distance, column + step, row), reach(distance, column, row + step)) + 1
                    let corner = min(reach(distance, column + step, row + step), reach(distance, column - step, row + step)) + diagonal
                    distance[row * width + column] = min(distance[row * width + column], near, corner)
                }
            }
        }
        guard let most = distance.max(), most > 0 else { return nil }
        let middle = (x: Double(width - 1) / 2, y: Double(height - 1) / 2)
        let deepest = distance.indices.filter { distance[$0] >= most - 0.5 }.min { first, second in
            let off = { (index: Int) in hypot(Double(index % width) - middle.x, Double(index / width) - middle.y) }
            return off(first) < off(second)
        } ?? 0
        return (deepest, distance[deepest])
    }

    /// Pixels across the longer side a layer's coverage is read at: a 112 px line's strokes are 2–3 samples thick.
    static let poleSamples = 256.0

    nonisolated private static let poleContext = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
}
