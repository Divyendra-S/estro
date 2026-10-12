//
//  MotionFrameRenderer+Reveal.swift
//  Reco
//

import CoreImage

/// Text revealed part by part: typed, wiped, rising, words, letters springing in, voice and replies, swept and brightened (spec
/// 0011, 0014, 0015, 0017).
nonisolated extension MotionFrameRenderer {

    /// A text layer's parts shown as far as `reveal` has got at `time`: each whole, or partly, by
    /// its style. Its image is drawn at its raster scale, rounded up to whole pixels.
    static func revealed(_ image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        let pixels = { (rect: CGRect) in revealPixels(of: rect, in: layer) }
        let extent = revealExtent(of: image, layer: layer)
        var shown = CIImage(color: .clear).cropped(to: extent)
        // A brightened line is there dim from its cut, its words lit over it
        if reveal.style == .brighten {
            shown = image.fading(to: TextReveal.brightenDim).composited(over: shown)
        }
        // Parts already shown in full, joined while they're on one line
        var whole: CGRect?
        for (index, part) in layer.parts.enumerated() {
            let fraction = reveal.fraction(ofPart: index, at: time)
            guard fraction > 0 else { break }
            if fraction >= 1 {
                if let run = whole, abs(run.minY - part.minY) < 0.5 {
                    whole = run.union(part)
                } else {
                    if let run = whole {
                        shown = image.cropped(to: pixels(run)).composited(over: shown)
                    }
                    whole = part
                }
                continue
            }
            let progress = reveal.progress(ofPart: index, at: time)
            if let piece = partway(image.cropped(to: pixels(part)), part: part, of: layer, style: reveal.style, progress: (progress, fraction)) {
                shown = piece.composited(over: shown)
            }
        }
        if let run = whole {
            shown = image.cropped(to: pixels(run)).composited(over: shown)
        }
        if reveal.style == .kinetic, layer.accent != nil {
            shown = kinetic(shown, image: image, of: layer, by: reveal, at: time)
        }
        if reveal.tintsInGradient {
            shown = voiced(shown, image: image, of: layer, by: reveal, at: time)
        }
        return shown.cropped(to: extent)
    }

    /// The layer's whole extent and the room its letters move in: the projection maps the extent to the quad around it.
    private static func revealExtent(of image: CIImage, layer: MotionPlan.Layer) -> CGRect {
        let room = layer.revealRoom
        return image.extent.insetBy(dx: -room.width * layer.rasterScale, dy: -room.height * layer.rasterScale)
    }

    /// A decode's or a dissolve's characters, each on its own time (``TextReveal/scrambled(_:stagger:)``): sharpening in from 8 %
    /// of its line and fading up, or the other way out; a decode's spread about the layer's anchor and closing up.
    static func scrambled(_ image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        let decode = reveal.style == .decode
        let end = reveal.end(parts: layer.parts.count)
        let extent = revealExtent(of: image, layer: layer)
        let clear = CIImage(color: .clear).cropped(to: extent)
        // Whole before a dissolve and once a decode has closed up: no character drawn alone
        if decode ? time >= end + TextReveal.decodeSettle : time <= reveal.start {
            return image.composited(over: clear)
        }
        let scale = layer.rasterScale
        let spread = decode ? reveal.spread(at: time, parts: layer.parts.count) : 0
        let anchor = layer.anchor.x * layer.size.width
        var shown = clear
        for (index, part) in layer.parts.enumerated() {
            let eased = reveal.progress(ofPart: index, at: time)
            let visible = decode ? eased : 1 - eased
            guard visible > 1e-3 else { continue }
            var piece = image.cropped(to: revealPixels(of: part, in: layer))
            if case let sigma = (1 - visible) * part.height * 0.08 * scale, sigma >= 0.3 {
                piece = piece.applyingGaussianBlur(sigma: sigma)
            }
            if spread > 0 {
                piece = piece.transformed(by: CGAffineTransform(translationX: ((part.midX - anchor) * spread * scale).rounded(), y: 0))
            }
            shown = piece.fading(to: visible).composited(over: shown)
        }
        return shown.cropped(to: extent)
    }

    /// The room letters spring through around their text, in lines across and down: from 0.7 of a line below to a
    /// quarter above at 1.35× (``TextReveal/letterPose(_:)``), each piece 0.15 of a line taller than its line.
    static let letterRoom = CGSize(width: 0.5, height: 1)

    /// A part's rectangle (canvas pixels from the layer's top-left) in its image's pixels, taller than its line for
    /// accents and descenders that reach past it.
    static func revealPixels(of rect: CGRect, in layer: MotionPlan.Layer) -> CGRect {
        let (scale, height) = (layer.rasterScale, layer.size.height)
        let rect = rect.insetBy(dx: 0, dy: -rect.height * 0.15)
        return CGRect(x: rect.minX * scale, y: (height - rect.maxY) * scale, width: rect.width * scale, height: rect.height * scale)
    }

    /// A part on its way in, `progress` of the way (eased, then not), as its style shows it; `nil` for a style that
    /// shows a part only whole.
    private static func partway(
        _ piece: CIImage, part: CGRect, of layer: MotionPlan.Layer, style: TextReveal.Style, progress: (eased: Double, fraction: Double)
    ) -> CIImage? {
        let (eased, line, scale) = (progress.eased, part.height, layer.rasterScale)
        switch style {
        // A decode's and a dissolve's are drawn by ``scrambled(_:of:by:at:)``
        case .type, .kinetic, .voice, .brighten, .decode, .dissolve:
            return nil
        case .reply:
            return piece.fading(to: eased)
        case .sweep:
            // On a straight ramp: the film's front was linear
            return piece.fading(to: progress.fraction)
        case .wipe:
            // Sharpens as it fades in: 8% of its line, 9.8 px for a 1080p headline (at most 10 on text)
            return piece.applyingGaussianBlur(sigma: (1 - eased) * line * 0.08 * scale).fading(to: eased)
        case .rise:
            return piece.transformed(by: CGAffineTransform(translationX: 0, y: -(1 - eased) * line * scale)).cropped(to: revealPixels(of: part, in: layer))
        case .word:
            // Up a quarter of its line, sharpening from 4% of it, as it fades in
            return piece.applyingGaussianBlur(sigma: (1 - eased) * line * 0.04 * scale)
                .transformed(by: CGAffineTransform(translationX: 0, y: -(1 - eased) * line * 0.25 * scale)).fading(to: eased)
        case .letter:
            // Grown about its middle and moved up from below, into the room around the layer
            let pose = TextReveal.letterPose(progress.fraction)
            let middle = CGPoint(x: piece.extent.midX, y: piece.extent.midY)
            let placed = CGAffineTransform(translationX: -middle.x, y: -middle.y)
                .concatenating(CGAffineTransform(scaleX: pose.scale, y: pose.scale))
                .concatenating(CGAffineTransform(translationX: middle.x, y: middle.y - pose.below * line * scale))
            return piece.transformed(by: placed).fading(to: pose.opacity)
        }
    }
}
