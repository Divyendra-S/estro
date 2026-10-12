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

    /// How a through or a dive into scene `index` sees the scene before `time` into it, in output pixels: magnified about its
    /// pole or source, log-even, that point coming to the frame's middle; `nil` for other seams and after it. The scene before is
    /// drawn through it from its layers' own images: its frame magnified (up to 60 times, into a letter's stroke) was a blur.
    static func seamView(into index: Int, at time: Double, plan: MotionPlan) -> CGAffineTransform? {
        guard let transition = plan.scenes[index].transition, time < transition.duration else { return nil }
        let size = plan.outputSize
        let progress = transition.progress(at: time)
        switch transition.seam {
        case .through:
            guard let pole = seamPole(into: index, at: time, plan: plan) else { return nil }
            return toward(pole.point, reach: throughReach(of: pole, rim: throughRimWidth(of: pole, size: size), size: size), progress: progress, size: size)
        case .dive:
            let source = expandSource(into: index, at: time, plan: plan)
            return toward(CGPoint(x: source.midX, y: source.midY), reach: diveReach(of: source, size: size), progress: progress, size: size)
        default:
            return nil
        }
    }

    /// Magnified about `point` `reach` times, log-even, `progress` of the way, the point coming to the frame's middle.
    static func toward(_ point: CGPoint, reach: Double, progress: Double, size: CGSize) -> CGAffineTransform {
        let centre = CGPoint(x: point.x + (size.width / 2 - point.x) * progress, y: point.y + (size.height / 2 - point.y) * progress)
        return scaling(about: point, by: pow(reach, progress), onto: centre)
    }

    /// The camera `progress` of the way into `matte` (the layer the seam is made of, drawn alone) at `pole`, with `scenes.before`
    /// already seen through the seam's view (``seamView(into:at:plan:)``): the next scene seen inside the shape, its own colour
    /// left round it as a rim, coming up from further back. The shape's edge is cut sharp as it's magnified.
    static func throughed(_ scenes: (before: CIImage, next: CIImage), matte: CIImage, pole: (point: CGPoint, radius: Double), progress: Double, size: CGSize) -> CIImage {
        let frame = CGRect(origin: .zero, size: size)
        let middle = CGPoint(x: frame.midX, y: frame.midY)
        let rim = throughRimWidth(of: pole, size: size)
        let reach = throughReach(of: pole, rim: rim, size: size)
        let view = toward(pole.point, reach: reach, progress: progress, size: size)
        let margin = frame.insetBy(dx: -size.width * 0.25, dy: -size.height * 0.25)
        // The shape less its rim, as a mask, fading in so the shape is itself at the cut
        let eroded = rim >= 0.5 ? matte.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: rim]) : matte
        let window = crisped(eroded.transformed(by: view).cropped(to: margin), solid: 1, sharpness: pow(reach, progress))
            .fading(to: min(progress / throughShow, 1))
        let depth = throughFrom + (1 - throughFrom) * progress
        let seen = scenes.next.transformed(by: scaling(about: middle, by: depth, onto: pole.point.applying(view)))
        return seen.cropped(to: frame).applyingFilter("CIBlendWithAlphaMask", parameters: [kCIInputBackgroundImageKey: scenes.before, kCIInputMaskImageKey: window])
            .cropped(to: frame)
    }

    /// The rim a through leaves round what's seen through its shape at `pole`, in output pixels before it's magnified.
    static func throughRimWidth(of pole: (point: CGPoint, radius: Double), size: CGSize) -> Double {
        min(throughRim * pole.radius, throughRimMost * size.height / 1080)
    }

    /// The seam made of a layer into scene `index`, `progress` of the way and `time` into it, if it's one and the layer is
    /// there; `nil` otherwise.
    static func madeOfLayer(_ scenes: (before: CIImage, next: CIImage), into index: Int, at time: Double, progress: Double, plan: MotionPlan) -> CIImage? {
        guard let transition = plan.scenes[index].transition else { return nil }
        let size = plan.outputSize
        switch transition.seam {
        case .through:
            guard let pole = seamPole(into: index, at: time, plan: plan), let matte = seamLayerImage(into: index, at: time, plan: plan) else { return nil }
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
    static func scaling(about point: CGPoint, by scale: Double, onto: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y).concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: onto.x, y: onto.y))
    }

    /// The shape keeps a quarter of its thickness in its own colour round what's seen through it, at most 12 px at 1080p; the
    /// next scene shows in it over the first 0.15 of the way, from 0.7 of its size, sharp; the flight ends a tenth past covering
    /// the frame.
    static let throughRim = 0.25
    static let throughRimMost = 12.0
    static let throughShow = 0.15
    static let throughFrom = 0.7
    static let throughOvershoot = 1.1
}
