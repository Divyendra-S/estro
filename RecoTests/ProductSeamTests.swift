//
//  ProductSeamTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Seams made of the product's own shapes (spec 0023): a `through` flying into a layer of the scene before, a `motif` turning
/// the frame over in a grid of it, and `by` naming what other seams open out of.
struct ProductSeamTests {

    /// A mark (an upward triangle) in the middle of a dark frame, then a scene the seam goes into.
    private static func plan(seam: String, from layer: String? = "mark", extra: String = "") async throws -> MotionPlan {
        let named = layer.map { #", "by": "\#($0)""# } ?? ""
        let json = #"""
            {"version": 1, "canvas": {"background": "#000000"}, "scenes": [
              {"id": "one", "duration": 2, "camera": {"moves": [{"move": "hold"}]}, "layers": [
                {"id": "mark", "transform": {"position": [700, 540, 0]}, "content": {"shape": {"kind": "triangle", "size": [300, 300], "color": "#ff0000"}}},
                {"id": "note", "transform": {"position": [1500, 300, 0]}, "content": {"shape": {"size": [200, 120], "color": "#ffffff"}}}\#(extra)]},
              {"id": "two", "duration": 2, "seam": "\#(seam)"\#(named), "camera": {"moves": [{"move": "hold"}]}}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        try document.validate()
        return await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 540)
    }

    private static func frames(_ plan: MotionPlan) -> (before: CIImage, next: CIImage) {
        let bounds = CGRect(origin: .zero, size: plan.outputSize)
        return (CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3)).cropped(to: bounds), CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.9)).cropped(to: bounds))
    }

    /// The pole is where the shape is thickest: a triangle's is its incentre, a third of its height up from its base. The glyph
    /// is an equilateral triangle as wide as the layer, its apex on the layer's top edge.
    @Test func aPoleIsWhereAShapeIsThickest() async throws {
        let plan = try await Self.plan(seam: "through")
        let pole = try #require(plan.scenes[1].pole)

        #expect(abs(pole.point.x - 0.5) < 0.03, "\(pole)")
        // Its inradius is 0.289 of its side, 86.6 px, its centre 0.87 − 0.289 of the way down
        #expect(abs(pole.point.y - 0.577) < 0.03, "\(pole)")
        #expect(abs(pole.radius - 86.6) < 9, "\(pole)")

        // A thin bar and a thick block: the block
        let (width, height) = (20, 10)
        let inside = (0..<width * height).map { index in
            let (column, row) = (index % width, index / width)
            return column < 10 ? row == 5 : (2...8).contains(row) && column < 18
        }
        let deepest = try #require(MotionPlan.farthestInside(inside, width: width, height: height))
        #expect((11...16).contains(deepest.index % width) && deepest.index / width == 5, "\(deepest)")
    }

    /// The camera flies into the shape: half way the next scene shows where the shape's pole has come to, the scene before is
    /// still round it; at the end it's the next scene everywhere. At the cut the mark is itself.
    @Test func aThroughFliesIntoItsShape() async throws {
        let plan = try await Self.plan(seam: "through")
        let (before, next) = Self.frames(plan)
        let draw = { (time: Double) in MotionFrameRenderer.transitioned(before, next, into: 1, at: time, plan: plan) }
        let size = plan.outputSize
        let pole = try #require(MotionFrameRenderer.seamPole(into: 1, at: 0, plan: plan))
        let progress = SeamExpansion.throughDuration * 0.5
        let eased = try #require(plan.scenes[1].transition).progress(at: progress)
        let centre = CGPoint(x: pole.point.x + (size.width / 2 - pole.point.x) * eased, y: pole.point.y + (size.height / 2 - pole.point.y) * eased)

        #expect(try Self.color(of: draw(0), at: pole.point) == Self.color(of: before, at: .zero))
        let middle = try draw(progress)
        let inside = try Self.color(of: middle, at: centre)
        #expect(inside[2] > 180, "\(inside)")
        #expect(try Self.color(of: middle, at: CGPoint(x: 2, y: 2)) == Self.color(of: before, at: .zero))
        let end = try draw(SeamExpansion.throughDuration)
        for corner in [CGPoint(x: 2, y: 2), CGPoint(x: size.width - 2, y: size.height - 2)] {
            #expect(try Self.color(of: end, at: corner) == Self.color(of: next, at: .zero))
        }
    }

    /// A motif: early, the shape pops up in its own colour in the cell where it was, while far cells still show the scene
    /// before; at the end, the next scene everywhere.
    @Test func aMotifTurnsTheFrameOverInItsShape() async throws {
        let plan = try await Self.plan(seam: "motif")
        let (before, next) = Self.frames(plan)
        let draw = { (time: Double) in MotionFrameRenderer.transitioned(before, next, into: 1, at: time, plan: plan) }
        let size = plan.outputSize
        let box = try #require(MotionFrameRenderer.seamLayerBox(into: 1, at: 0, plan: plan))
        // The grid is centred on the shape, its copy there drawn about its pole
        let own = CGPoint(x: box.midX, y: box.midY)

        let early = try draw(SeamExpansion.motifDuration * 0.06)
        let popped = try Self.color(of: early, at: own)
        #expect(popped[0] > 150, "\(popped)")
        #expect(try Self.color(of: draw(SeamExpansion.motifDuration * 0.5), at: own)[2] > 180)
        let far = try Self.color(of: early, at: CGPoint(x: size.width - 2, y: 2))
        #expect(far[0] == far[2] && far[0] > 40, "\(far)")
        let (end, blue) = (try Self.color(of: draw(SeamExpansion.motifDuration), at: CGPoint(x: size.width - 2, y: 2)), try Self.color(of: next, at: .zero))
        #expect(zip(end, blue).allSatisfy { abs(Int($0) - Int($1)) <= 1 }, "\(end) \(blue)")
    }

    /// by names what an expand opens out of instead of the last click.
    @Test func anExpandOpensOutOfItsLayer() async throws {
        let plan = try await Self.plan(seam: "expand", from: "note")
        let source = MotionFrameRenderer.expandSource(into: 1, plan: plan)
        let scale = plan.outputScale

        #expect(abs(source.midX - 1500 * scale) < 1 && abs(source.midY - (1080 - 300) * scale) < 1, "\(source)")
        #expect(abs(source.width - 200 * scale) < 1, "\(source)")
    }

    /// A through or motif needs by, by names a layer of the scene before, and only seams made of a layer or opening out of one
    /// take it.
    @Test func byIsChecked() async throws {
        await #expect(throws: MotionDocumentError.self) { try await Self.plan(seam: "through", from: nil) }
        await #expect(throws: MotionDocumentError.self) { try await Self.plan(seam: "motif", from: "nothing") }
        await #expect(throws: MotionDocumentError.self) { try await Self.plan(seam: "cut") }
        _ = try await Self.plan(seam: "dive")
    }

    /// A through sounds as a dive (air rising to its fastest), a motif as tiles (a swish and a landing).
    @Test func eachSoundsAsItMoves() async throws {
        let (through, motif) = (try await Self.plan(seam: "through"), try await Self.plan(seam: "motif"))
        #expect(through.sound.cues.contains { if case .riser = $0.voice { $0.time > 2 } else { false } })
        #expect(motif.sound.cues.contains { if case .swish = $0.voice { $0.time >= 2 } else { false } })
    }

    // MARK: - Helpers

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The RGB bytes of the pixel at `point` (Core Image's coordinates, from the bottom left).
    private static func color(of image: CIImage, at point: CGPoint) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let pixel = CGRect(x: point.x.rounded(.down), y: point.y.rounded(.down), width: 1, height: 1)
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: pixel, format: .RGBA8, colorSpace: nil)
        return Array(bytes.prefix(3))
    }
}
