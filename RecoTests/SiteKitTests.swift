//
//  SiteKitTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Films made of the site's own kit, seen sharp (spec 0026): what inspect_page reads and shows of a site (its colours however
/// small, its panels, a picture of it), a zoom through the scene before drawn from its layers, an expand turning to the next
/// scene's ground, and a line repeated through a film named.
@MainActor
struct SiteKitTests {

    private static func script(_ page: String, viewport: CGSize = CGSize(width: 640, height: 400)) -> WebScript {
        var script = WebScript()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        script.viewport = viewport
        script.scale = 1
        script.duration = 0.5
        return script
    }

    /// A dark page's small purple bars, green status and translucent red row are its colours, each with the words beside it,
    /// and no grey is; its panels' translucent fill, border and corners are its surface.
    @Test func inspectingReadsTheSitesColoursAndPanels() async throws {
        let panel = "border-radius: 24px; background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.1); width: 400px; height: 90px; margin: 8px"
        let page = """
            <!doctype html><html><body style="margin: 0; background: #080808; color: #f0f0f0; font: 14px sans-serif">
            <div style="\(panel)"><span>agent run: 'ops-agent'</span><div style="width: 120px; height: 6px; background: #a78bfa"></div></div>
            <div style="\(panel)"><span style="color: #22c55e">Passed</span></div>
            <div style="\(panel)"><div style="background: rgba(239, 68, 68, 0.3)">Failed: rain expected</div></div>
            </body></html>
            """
        let brand = try #require(try await WebPageRenderer(script: Self.script(page)).inspect(selectors: []).brand)
        let colors = try #require(brand.colors)

        let purple = try #require(colors.first { $0.color == "#a78bfa" })
        #expect(purple.used == ["fill"] && purple.near.contains { $0.contains("agent run") }, "\(purple)")
        #expect(colors.contains { $0.color == "#22c55e" && $0.used.contains("text") })
        let red = try #require(colors.first { $0.near.contains { $0.contains("Failed") } })
        #expect(red.color.hasPrefix("#e") || red.color.hasPrefix("#f"), "\(red)")
        // No greys: the ground, the text and the panels' white are the palette's
        #expect(!colors.contains { ["#080808", "#f0f0f0", "#ffffff"].contains($0.color) })
        #expect(brand.surface == PageInspection.Surface(background: "#ffffff0a", border: "1px #ffffff1a", radius: 24), "\(String(describing: brand.surface))")
    }

    /// Looking, the page comes back screen by screen from its top to its foot in one sheet, three across.
    @Test func inspectingLooksAtThePageTopToFoot() async throws {
        let page = """
            <!doctype html><html><body style="margin: 0">
            <div style="height: 400px; background: rgb(255, 0, 0)"></div><div style="height: 400px; background: rgb(0, 255, 0)"></div>
            <div style="height: 400px; background: rgb(0, 0, 255)"></div></body></html>
            """
        let (_, look) = try await WebPageRenderer(script: Self.script(page)).inspect(selectors: [], looking: true)
        let sheet = try #require(look)
        let tile = WebPageRenderer.lookTileWidth

        #expect(sheet.width == 3 * tile + 2 * ContactSheet.gap && sheet.height == 400)
        let image = CIImage(cgImage: sheet)
        let middle = { (column: Int) in try Self.color(of: image, at: CGPoint(x: column * (tile + ContactSheet.gap) + tile / 2, y: 200)) }
        let (top, between, foot) = (try middle(0), try middle(1), try middle(2))
        #expect(top[0] > 200 && between[1] > 200 && foot[2] > 200, "\(top) \(between) \(foot)")
    }

    /// A through into a big letter is drawn from the scene's own layers through the magnified view, with crisp edges: half way,
    /// magnified tens of times, the middle row crosses the letter's edges in a few pixels, not a blur as wide as the zoom.
    @Test func aThroughStaysSharpAllTheWay() async throws {
        let json = #"""
            {"version": 1, "canvas": {"background": "#000000", "field": "plain"}, "scenes": [
              {"id": "one", "duration": 2, "camera": {"moves": [{"move": "hold"}]}, "layers": [
                {"id": "word", "transform": {"position": [960, 540, 0]}, "content": {"text": {"text": "O", "size": 700, "color": "#ffffff", "weight": "bold"}}}]},
              {"id": "two", "duration": 2, "seam": "through", "by": "word", "camera": {"moves": [{"move": "hold"}]}, "layers": [
                {"id": "ground", "transform": {"position": [960, 540, 0]}, "content": {"shape": {"size": [1920, 1080], "color": "#0000ff"}}}]}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        try document.validate()
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 540)
        let transition = try #require(plan.scenes[1].transition)
        let time = transition.duration * 0.55
        let pole = try #require(MotionFrameRenderer.seamPole(into: 1, at: time, plan: plan))
        let reach = MotionFrameRenderer.throughReach(of: pole, rim: MotionFrameRenderer.throughRimWidth(of: pole, size: plan.outputSize), size: plan.outputSize)
        #expect(pow(reach, transition.progress(at: time)) > 6)

        let size = plan.outputSize
        let pixels = try MotionDesignTests.pixels(of: MotionFrameRenderer.image(at: plan.scenes[1].start + time, plan: plan), size: size)
        let width = Int(size.width)
        let row = Int(size.height) / 2
        // Neither the white letter, the black ground nor the blue scene inside it
        let soft = (0..<width).filter { column in
            let pixel = Array(pixels[(row * width + column) * 4..<(row * width + column) * 4 + 3]).map(Int.init)
            let isWhite = pixel.allSatisfy { $0 > 215 }, isBlack = pixel.allSatisfy { $0 < 40 }, isBlue = pixel[2] > 215 && pixel[0] < 40 && pixel[1] < 40
            return !isWhite && !isBlack && !isBlue
        }
        #expect(soft.count <= 12, "\(soft.count) soft pixels of \(width)")
    }

    /// An expand's rectangle turns to the next scene's ground, not the average of its frame: a white control into a blue scene
    /// with a white card is blue round the card, never a grey slab.
    @Test func anExpandTurnsToTheNextScenesGround() throws {
        let size = CGSize(width: 240, height: 135)
        let frame = CGRect(origin: .zero, size: size)
        let source = CGRect(x: 110, y: 58, width: 20, height: 20)
        let before = CIImage(color: .white).cropped(to: source).composited(over: CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: frame))
        let ground = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: frame)
        let next = CIImage(color: .white).cropped(to: frame.insetBy(dx: 60, dy: 34)).composited(over: ground)
        let drawn = MotionFrameRenderer.expanded(before, into: next, from: source, progress: 0.32, ground: ground)

        // Inside the rectangle, outside the card as it comes up
        let rim = try Self.color(of: drawn, at: CGPoint(x: size.width / 2, y: 50))
        #expect(rim[2] > 150 && rim[0] < 90 && rim[1] < 90, "\(rim)")
    }

    /// A thin line of one colour drawn on its own in three scenes is named; in two, or as a part of a group (a trace's bar), not.
    @Test func aLineRepeatedThroughTheFilmIsNamed() throws {
        let line = ##"{"id": "line", "content": {"shape": {"size": [400, 6], "color": "#6fe38a"}}, "transform": {"position": [500, 700, 0]}}"##
        let bar = #"{"id": "row", "content": {"group": [\#(line)]}}"#
        let film = { (layers: [String]) throws -> MotionDocument in
            let scenes = layers.enumerated().map { #"{"id": "s\#($0.offset)", "duration": 2, "layers": [\#($0.element)]}"# }
            return try JSONDecoder().decode(MotionDocument.self, from: Data(#"{"version": 1, "scenes": [\#(scenes.joined(separator: ","))]}"#.utf8))
        }
        let ornaments = { (layers: [String]) throws in MotionLint.findings(in: try film(layers)).filter { $0.rule == .ornament } }

        #expect(try ornaments([line, line, line]).map(\.scene) == ["s0"])
        #expect(try ornaments([line, line, bar]).isEmpty)
        #expect(try ornaments([line, line]).isEmpty)
    }

    /// A pan or a push is blurred at most 13 px at 1080p, so its type reads; a whip streaks the whole of its travel.
    @Test func onlyAWhipStreaks() {
        let size = CGSize(width: 1920, height: 1080)
        let shutter = 0.5 / 60
        let length = { (widthsASecond: Double) in
            MotionFrameRenderer.blurLength(of: widthsASecond * size.width * shutter, across: shutter, size: size)
        }
        #expect(abs(length(3.75) - MotionFrameRenderer.blurMost * size.height) < 1e-9)
        #expect(abs(length(8) - 8 * size.width * shutter) < 1e-9)
        #expect(abs(length(0.2) - 0.2 * size.width * shutter) < 1e-9)
    }

    /// A flow's layers slide and fade, sharp, and twelve of them go within 0.15 s.
    @Test func aFlowIsSharpAndQuick() async throws {
        let lines = (0..<12).map {
            #"{"id": "line\#($0)", "content": {"text": {"text": "const x = \#($0);", "size": 40}}, "transform": {"position": [700, \#(200 + $0 * 50), 0]}}"#
        }
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2, "layers": [\#(lines.joined(separator: ","))]}, "#
            + #"{"id": "two", "duration": 2, "seam": "flow", "layers": [{"id": "box", "content": {"shape": {"size": [600, 200], "color": "333333"}}}]}]}"#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
        let (one, two) = (plan.scenes[0], plan.scenes[1])

        #expect(one.layers.allSatisfy { $0.value(.blur, at: 2.1) == 0 } && two.layers.allSatisfy { $0.value(.blur, at: 0.1) == 0 })
        let gone = { (layer: MotionPlan.Layer) in stride(from: 1.5, through: 3, by: 0.01).first { layer.value(.opacity, at: $0) < 0.01 } ?? 3 }
        let times = one.layers.map(gone)
        #expect((times.max() ?? 0) - (times.min() ?? 0) <= MotionPlan.flowStagger.within + 0.011, "\(times)")
    }

    /// Across a flow, what leaves and what arrives are never both all but gone: the frame never empties to the ground.
    @Test func aFlowNeverEmptiesTheFrame() async throws {
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2, "layers": [{"id": "card", "content": {"shape": {"size": [600, 200], "color": "333333"}}}]}, "#
            + #"{"id": "two", "duration": 2, "seam": "flow", "layers": [{"id": "box", "content": {"shape": {"size": [400, 300], "color": "333333"}}}]}]}"#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
        let (one, two) = (plan.scenes[0], plan.scenes[1])

        for time in stride(from: -0.2, through: 0.3, by: 0.01) {
            let seen = max(one.layers[0].value(.opacity, at: one.duration + time), time >= 0 ? two.layers[0].value(.opacity, at: time) : 0)
            #expect(seen > 0.3, "\(time): \(seen)")
        }
    }

    /// A layer carried out of a group stays seen across a flow while the group's other parts leave and arrive round it.
    @Test func aFlowCarriesALayerOutOfItsGroup() async throws {
        let part = { (id: String, content: String) in #"{"id": "\#(id)", "content": \#(content)}"# }
        let (title, fill) = (#"{"text": {"text": "Stapler", "size": 40}}"#, #"{"shape": {"size": [600, 200], "color": "eeeeee"}}"#)
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2, "layers": [{"id": "card", "content": {"group": ["#
            + part("fill", fill) + "," + part("title", title) + #"]}}]}, {"id": "two", "duration": 2, "seam": "flow", "layers": ["#
            + #"{"id": "chip", "content": {"group": ["# + part("dot", fill) + "," + part("title", title) + "]}}]}]}"
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
        let seen = { (scene: MotionPlan.Scene, id: String, time: Double) -> Double in
            var (index, opacity) = (scene.layers.firstIndex { $0.id == id }, 1.0)
            while let layer = index {
                opacity *= scene.layers[layer].value(.opacity, at: time)
                index = scene.layers[layer].parent
            }
            return opacity
        }
        let (one, two) = (plan.scenes[0], plan.scenes[1])

        #expect(seen(one, "title", one.duration + 0.1) > 0.99 && seen(two, "title", 0) > 0.99)
        #expect(seen(one, "fill", one.duration + 0.1) < 0.01 && seen(two, "dot", 0) < 0.01)
    }

    /// A mark lifted in one colour keeps sharp edges magnified, as a text does.
    @Test func aTintedMarkIsCrisped() async throws {
        let json = ##"{"version": 1, "assets": [{"id": "logo", "url": "https://example.com", "selector": "svg"}], "scenes": [{"id": "one", "duration": 2, "layers": ["##
            + ##"{"id": "mark", "content": {"ui": {"asset": "logo", "tint": "#ffffff"}}}, {"id": "word", "content": {"text": {"text": "Hi", "color": "#ffffffcc"}}}]}]}"##
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
        let layers = plan.scenes[0].layers
        #expect(layers.first { $0.id == "mark" }?.solidAlpha == 1)
        #expect(abs((layers.first { $0.id == "word" }?.solidAlpha ?? 0) - 0.8) < 0.01)
    }

    private static func color(of image: CIImage, at point: CGPoint) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let pixel = CGRect(x: point.x.rounded(.down), y: point.y.rounded(.down), width: 1, height: 1)
        CIContext(options: [.workingColorSpace: NSNull()]).render(image, toBitmap: &bytes, rowBytes: 4, bounds: pixel, format: .RGBA8, colorSpace: nil)
        return Array(bytes.prefix(3))
    }
}
