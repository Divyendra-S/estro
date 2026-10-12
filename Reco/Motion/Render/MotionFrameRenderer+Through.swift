//
//  MotionFrameRenderer+Through.swift
//  Reco
//

import CoreImage

/// Seams made of the product's own shapes (spec 0023): the layer a scene's `by` names in the scene before, drawn alone, is what
/// a `through` flies into and what a `motif`'s grid is made of; an expand, dive, iris, liquid or tiles open out of it.
nonisolated extension MotionFrameRenderer {

    /// The layer the seam into scene `index` is made of, with everything in it, drawn alone in output pixels where it is `time`
    /// into the seam (the scene before goes on under it); `nil` without one.
    static func seamLayerImage(into index: Int, at time: Double, plan: MotionPlan) -> CIImage? {
        guard index > 0, let layer = plan.scenes[index].opensFrom else { return nil }
        let scene = plan.scenes[index - 1]
        let sceneTime = scene.duration + time
        let placements = plan.placements(of: scene, at: sceneTime)
        let field = ground(index - 1, at: sceneTime, plan: plan)
        return placements.filter { scene.isLayer($0.layer, within: layer) }.reduce(CIImage.empty()) { image, placement in
            layerImage(placement, in: index - 1, over: field, at: sceneTime, placements: placements, plan: plan, frames: [:])
                .map { $0.composited(over: image) } ?? image
        }
    }

    /// The box of that layer and everything in it, in output pixels, where it is `time` into the seam.
    static func seamLayerBox(into index: Int, at time: Double, plan: MotionPlan) -> CGRect? {
        guard index > 0, let layer = plan.scenes[index].opensFrom else { return nil }
        let scene = plan.scenes[index - 1]
        let corners = plan.placements(of: scene, at: scene.duration + time).filter { scene.isLayer($0.layer, within: layer) }.flatMap(\.corners)
        guard let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
              let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max() else { return nil }
        let scale = plan.outputScale
        return CGRect(x: minX * scale, y: (plan.canvas.height - maxY) * scale, width: (maxX - minX) * scale, height: (maxY - minY) * scale)
    }

    /// Where that layer is thickest on screen `time` into the seam, and how far that is from its nearest edge, in output pixels.
    static func seamPole(into index: Int, at time: Double, plan: MotionPlan) -> (point: CGPoint, radius: Double)? {
        guard index > 0, let pole = plan.scenes[index].pole else { return nil }
        let scene = plan.scenes[index - 1]
        let sceneTime = scene.duration + time
        guard let corners = plan.placements(of: scene, at: sceneTime).first(where: { $0.layer == pole.layer })?.corners, corners.count == 4 else {
            return seamLayerBox(into: index, at: time, plan: plan).map { (CGPoint(x: $0.midX, y: $0.midY), min($0.width, $0.height) / 2) }
        }
        let mix = { (start: CGPoint, end: CGPoint, share: Double) in CGPoint(x: start.x + (end.x - start.x) * share, y: start.y + (end.y - start.y) * share) }
        let (top, bottom) = (mix(corners[0], corners[1], pole.point.x), mix(corners[3], corners[2], pole.point.x))
        let point = mix(top, bottom, pole.point.y)
        // Canvas pixels on screen a pixel of the layer: its top edge's length over its width
        let shown = hypot(corners[1].x - corners[0].x, corners[1].y - corners[0].y) / max(scene.layers[pole.layer].size(at: sceneTime).width, 1)
        let scale = plan.outputScale
        return (CGPoint(x: point.x * scale, y: (plan.canvas.height - point.y) * scale), pole.radius * shown * scale)
    }

    /// The camera `progress` of the way into `matte` (the layer the seam is made of, drawn alone) at `pole`: the scene before
    /// magnified about it, log-even, the pole coming to the frame's middle, until the shape covers the frame; the next scene seen
    /// inside the shape, its own colour left round it as a rim, coming up from further back and out of a blur.
    static func throughed(_ scenes: (before: CIImage, next: CIImage), matte: CIImage, pole: (point: CGPoint, radius: Double), progress: Double, size: CGSize) -> CIImage {
        let frame = CGRect(origin: .zero, size: size)
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        let unit = size.height / 1080
        let rim = min(throughRim * pole.radius, throughRimMost * unit)
        let zoom = pow(throughReach(of: pole, rim: rim, size: size), progress)
        let centre = CGPoint(x: pole.point.x + (middle.x - pole.point.x) * progress, y: pole.point.y + (middle.y - pole.point.y) * progress)
        let toward = scaling(about: pole.point, by: zoom, onto: centre)
        let margin = frame.insetBy(dx: -size.width * 0.25, dy: -size.height * 0.25)
        let plane = scenes.before.clampedToExtent().transformed(by: toward).cropped(to: margin)
        // The shape less its rim, as a mask, fading in so the shape is itself at the cut
        let eroded = rim >= 0.5 ? matte.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: rim]) : matte
        let window = eroded.transformed(by: toward).cropped(to: margin).fading(to: min(progress / throughShow, 1))
        let depth = throughFrom + (1 - throughFrom) * progress
        var seen = scenes.next.transformed(by: scaling(about: middle, by: depth, onto: centre))
        let blur = throughBlur * unit * (1 - progress)
        if blur >= 0.3 {
            seen = seen.clampedToExtent().applyingGaussianBlur(sigma: blur)
        }
        return seen.cropped(to: frame).applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: plane, kCIInputMaskImageKey: window])
            .cropped(to: frame)
    }

    /// The seam made of a layer into scene `index`, `progress` of the way and `time` into it, if it's one and the layer is
    /// there; `nil` otherwise.
    static func madeOfLayer(_ scenes: (before: CIImage, next: CIImage), into index: Int, at time: Double, progress: Double, plan: MotionPlan) -> CIImage? {
        guard let transition = plan.scenes[index].transition else { return nil }
        let size = plan.outputSize
        switch transition.seam {
        case .through:
            guard let matte = seamLayerImage(into: index, at: time, plan: plan), let pole = seamPole(into: index, at: time, plan: plan) else { return nil }
            return throughed(scenes, matte: matte, pole: pole, progress: progress, size: size)
        case .motif:
            // The shape as it was at the cut, so the grid's cells don't change as the scene before goes on
            guard let shape = seamLayerImage(into: index, at: 0, plan: plan), let box = seamLayerBox(into: index, at: 0, plan: plan),
                  let pole = seamPole(into: index, at: 0, plan: plan) else { return nil }
            return TransitionRenderer.motif(transition, between: scenes, shape: (shape.cropped(to: box), pole), progress: progress, size: size)
        default:
            return nil
        }
    }

    /// How many times closer a through at `pole` ends: the shape less its `rim` covers the frame from its middle, a little past.
    static func throughReach(of pole: (point: CGPoint, radius: Double), rim: Double, size: CGSize) -> Double {
        max(hypot(size.width, size.height) / 2 / max(pole.radius - rim, 1) * throughOvershoot, 1)
    }

    /// Scaling by `scale` about `point`, then moving `point` onto `onto`.
    private static func scaling(about point: CGPoint, by scale: Double, onto: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: onto.x, y: onto.y))
    }

    /// The shape keeps a quarter of its thickness in its own colour round what's seen through it, at most 12 px at 1080p; the
    /// next scene shows in it over the first 0.15 of the way, from 0.7 of its size out of a 12 px blur; the flight ends a tenth
    /// past covering the frame.
    static let throughRim = 0.25
    static let throughRimMost = 12.0
    static let throughShow = 0.15
    static let throughFrom = 0.7
    static let throughBlur = 12.0
    static let throughOvershoot = 1.1
}
