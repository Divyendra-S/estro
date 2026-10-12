//
//  MotionFrameRenderer+Sharpness.swift
//  Reco
//

import CoreImage

/// What keeps a frame sharp as things grow and move (spec 0026): edges cut crisp past a layer's raster, and motion blur held
/// short of a whip.
nonisolated extension MotionFrameRenderer {

    /// `image` with the edges of what's `solid` (its alpha where it's whole) cut half way up, over a pixel: an edge magnified
    /// `sharpness` times from its image spans that many pixels, and a flat colour's (a text's) stays where it was. A magnified
    /// mask, likewise. Core Image's colour matrix works on unpremultiplied colour, so a text's colour is kept.
    static func crisped(_ image: CIImage, solid: Double, sharpness: Double) -> CIImage {
        guard solid > 0 else { return image }
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: sharpness),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: solid * 0.5 * (1 - sharpness))
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0), "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: solid)
        ])
    }

    /// How many times past its raster scale a text or a mark is drawn before its edges are cut sharp: up to it, the
    /// projection's own smoothing is an edge's antialiasing.
    static let crispPast = 1.5

    /// How far the planes and pointers on screen at `time` move while a shutter `shutter` seconds long is open, in
    /// output pixels: the most any of their corners (held inside the frame) or tips travels. Layers drawn sharp don't count.
    static func travel(at time: Double, across shutter: Double, plan: MotionPlan) -> Double {
        let (scene, sceneTime) = plan.scene(at: time)
        let (opens, closes) = (sceneTime - shutter / 2, sceneTime + shutter / 2)
        // Corners held inside the frame: zoomed, a panel's far corners off screen swept faster than anything seen
        let frame = CGRect(origin: .zero, size: plan.canvas)
        let held = { (point: CGPoint) in CGPoint(x: min(max(point.x, frame.minX), frame.maxX), y: min(max(point.y, frame.minY), frame.maxY)) }
        let moving = { (time: Double) in
            plan.placements(of: scene, at: time).filter { !scene.layers[$0.layer].isSharp }.map { ($0.layer, $0.corners.map(held)) }
        }
        let closing = Dictionary(moving(closes)) { first, _ in first }
        let travel = moving(opens).map { layer, opening in
            closing[layer].map { corners in
                zip(opening, corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
            } ?? 0
        }
        let pointers = zip(pointerTips(of: scene, at: opens, plan: plan), pointerTips(of: scene, at: closes, plan: plan)).map { tips in
            tips.0.flatMap { from in tips.1.map { hypot($0.x - from.x, $0.y - from.y) } } ?? 0
        }
        return max(((travel + pointers).max() ?? 0) * plan.outputScale, seamTravel(into: plan.sceneIndex(at: time), at: sceneTime, across: shutter, plan: plan))
    }

    /// How far a frame is blurred when what's on it travels `travel` output pixels while the shutter is open: a whip (5 frame
    /// widths a second, as ``SoundRules/whipSpeed`` finds one) streaks all the way; a pan or a push at most ``blurMost`` of the
    /// frame's height, so its type stays readable, rising to the whole of it from ``blurFreeFrom`` widths a second. Mastra 5's
    /// zoom-pan of 2× in 0.55 s (3.75 widths a second) smeared its eval table's words about 60 px at 1080p; now 13.
    static func blurLength(of travel: Double, across shutter: Double, size: CGSize) -> Double {
        let most = blurMost * size.height
        guard travel > most, shutter > 0 else { return travel }
        let speed = travel / shutter / size.width
        let free = min(max((speed - blurFreeFrom) / (SoundRules.whipSpeed - blurFreeFrom), 0), 1)
        return most + (travel - most) * free * free * (3 - 2 * free)
    }

    /// 13 px at 1080p, 26 at 4K.
    static let blurMost = 0.012
    static let blurFreeFrom = 4.0
}
