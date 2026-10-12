//
//  TransitionRenderer+Motif.swift
//  Reco
//

import CoreImage

/// A motif (``MotionSeam/motif``, spec 0023): the frame turned over in a grid of the product's own shape.
nonisolated extension TransitionRenderer {

    /// The scene before into the next, `progress` (linear) of the way, in a grid of `shape.image` (the layer the seam is made of,
    /// drawn alone and cut to its box, in output pixels) out of where it is; `shape.pole` is where it's thickest and how far
    /// that is from its edge, so each copy, grown about it, ends covering its cell.
    static func motif(
        _ transition: SeamExpansion.Transition, between scenes: (before: CIImage, next: CIImage), shape: (image: CIImage, pole: (point: CGPoint, radius: Double)),
        progress: Double, size: CGSize
    ) -> CIImage {
        let box = shape.image.extent
        guard !box.isEmpty, !box.isInfinite else { return scenes.next }
        let side = motifSide * size.height / 1080
        // At its size in a cell the shape's longer side is ``motifFill`` of it
        let fit = side * motifFill / max(box.width, box.height)
        let pole = shape.pole.point
        // It grows until a disc round its pole covers the cell, no further than its 3 × 3 cells reach
        let covers = side * 0.5.squareRoot() / max(shape.pole.radius * fit, 0.5)
        let reach = [box.minX, box.maxX].flatMap { edge in [box.minY, box.maxY].map { hypot(edge - pole.x, $0 - pole.y) } }.max() ?? 1
        let most = max(min(covers * 1.1, 1.5 * side / max(reach * fit, 0.5)), 1)
        let turn = motifTurn * .pi / 180 * (transition.variant.isMultiple(of: 2) ? 1 : -1)
        let image = apply("motifSeam", [
            scenes.before.clampedToExtent(), scenes.next.clampedToExtent(), shape.image,
            CIVector(x: size.width, y: size.height, z: size.height / 1080, w: progress), CIVector(x: side, y: motifWave, z: box.midX, w: box.midY),
            CIVector(x: pole.x, y: pole.y, z: fit, w: most), CIVector(x: motifLag, y: turn, z: motifPop, w: 0)
        ], size: size)
        return (image ?? scenes.next).cropped(to: CGRect(origin: .zero, size: size))
    }

    /// Cells 160 px a side at 1080p (under seven rows), the shape's longer side 0.62 of one; the farthest starts 0.5 of the seam
    /// after the nearest; a copy pops over the first 0.4 of its way, turning upright from 25°, and the next scene follows it
    /// 0.16 behind.
    static let motifSide = 160.0
    static let motifFill = 0.62
    static let motifWave = 0.5
    static let motifPop = 0.4
    static let motifTurn = 25.0
    static let motifLag = 0.16
}
