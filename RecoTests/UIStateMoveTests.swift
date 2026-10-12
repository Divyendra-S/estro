//
//  UIStateMoveTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

/// UI changing state as the thing itself (spec 0025): a text turning into the next letter by letter, a list on a drum turning
/// to its choice, and a scene of parts shown and hidden at once named.
struct UIStateMoveTests {

    private let bundle = URL.temporaryDirectory

    private func document(_ layers: String, duration: Double = 3) throws -> MotionDocument {
        let scene = MotionScene(id: "scene", duration: duration, layers: try JSONDecoder().decode([MotionLayer].self, from: Data(layers.utf8)))
        var document = MotionDocument(scenes: [scene])
        document.canvas.frameRate = 30
        document.canvas.field = .plain
        document.canvas.background = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        return document
    }

    private func label(_ moves: String) -> String {
        #"[{"id": "status", "content": {"text": {"text": "Running", "size": 120, "color": "ffffff"}}, "transform": {"position": [960, 540, 0]}, "moves": \#(moves)}]"#
    }

    @Test func scrambledPartsComeOutOfOrderWithinTheirTime() {
        let offsets = TextReveal.scrambled(12, stagger: 0.03)
        #expect(zip(offsets, offsets.dropFirst()).contains { $0 > $1 })
        #expect(offsets.allSatisfy { $0 >= 0 && $0 < (11 + TextReveal.scrambleReach) * 0.03 })
        #expect(offsets == TextReveal.scrambled(12, stagger: 0.03))

        var context = MoveContext(sceneDuration: 3, canvas: CGSize(width: 1920, height: 1080))
        context.characters = 12
        let reveal = MoveExpansion.scrambledReveal(of: MotionMove(.decode, start: 1, duration: 0.45), start: 1, duration: 0.45, in: context)
        #expect(reveal.end(parts: 12) <= 1.45 + 1e-9 && reveal.end(parts: 12) > 1.3)
        // Spread at its start, closed up once it has settled
        #expect(abs(reveal.spread(at: 1, parts: 12) - TextReveal.decodeSpread) < 1e-9)
        #expect(reveal.spread(at: 1.45 + TextReveal.decodeSettle, parts: 12) < 1e-9)
    }

    /// The text becomes a group of its states at its anchor: the old leaves as the new arrives, each there only while it's drawn.
    @Test func aRetextTurnsOneTextIntoTheNextAtItsPlace() async throws {
        let document = try document(label(#"[{"move": "fadeUp", "start": 0.1}, {"move": "retext", "start": 1, "words": ["Success"]}]"#))
        let expanded = DocumentExpansion.expanded(document, sizes: [:])
        let group = expanded.scenes[0].layers[0]
        guard case .group(let states) = group.content, states.count == 2,
              case .text(let before) = states[0].content, case .text(let after) = states[1].content else {
            Issue.record("A retext is a group of its two states")
            return
        }
        #expect(before.text == "Running" && after.text == "Success")
        #expect(group.moves.map(\.kind) == [.fadeUp])
        #expect(states[0].moves.map(\.kind) == [.dissolve] && states[1].moves.map(\.kind) == [.decode])
        #expect(states[1].moves[0].start == 1 + MoveExpansion.retextLag)

        let plan = await MotionPlan.build(document, bundle: bundle, shorterSide: 270, frameRate: 30)
        let opacity = { (layer: Int, time: Double) in
            plan.placements(of: plan.scenes[0], at: time).first { $0.layer == layer }?.opacity ?? 0
        }
        #expect(opacity(1, 0.9) > 0.99 && opacity(2, 0.9) == 0)
        #expect(opacity(1, 1 + MoveExpansion.dissolveDuration + 0.05) == 0 && opacity(2, 2) > 0.99)
        // Both drawn round the same anchor: the old text whole before, the new one after
        let lit = { (time: Double) in
            try MotionDesignTests.box(of: MotionFrameRenderer.image(at: time, plan: plan), size: plan.outputSize) { $0[0] > 128 }
        }
        let (old, new) = (try lit(0.9), try lit(2.5))
        #expect(abs(old.midX - new.midX) < 2 && abs(old.midY - new.midY) < 4 && abs(old.width - new.width) > 2)
    }

    /// A decode's letters start spread about the anchor, beyond the text's box, and close up onto it.
    @Test func aDecodesLettersCloseUpOntoTheirPlace() async throws {
        let plan = await MotionPlan.build(try document(label(#"[{"move": "decode", "start": 0.5, "duration": 0.6}]"#)), bundle: bundle, shorterSide: 270, frameRate: 30)
        #expect(plan.scenes[0].layers[0].revealRoom.width > 0)
        let lit = { (time: Double) in
            try MotionDesignTests.box(of: MotionFrameRenderer.image(at: time, plan: plan), size: plan.outputSize) { $0[0] > 40 }
        }
        #expect(try lit(0.4).isEmpty)
        let settled = try lit(2)
        let spread = try lit(0.5 + 0.6 - TextReveal.decodePart)
        #expect(spread.width > settled.width + 1)
    }

    /// Rows sit on a drum about the group's place, the front one whole; turned two rows, the row two below is in front.
    @Test func aWheelTurnsItsRowsOnADrum() throws {
        let rows = (-2...2).map { index in
            #"{"id": "row\#(index + 2)", "content": {"text": {"text": "Model \#(index + 2)", "size": 40, "color": "ffffff"}}, "transform": {"position": [0, \#(index * 88), 0]}}"#
        }.joined(separator: ", ")
        let menu = #"[{"id": "menu", "content": {"group": [\#(rows)]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "wheel", "start": 0.5, "intensity": 2}]}]"#
        let expanded = DocumentExpansion.expanded(try document(menu), sizes: [:])
        guard case .group(let placed) = expanded.scenes[0].layers[0].content else {
            Issue.record("The wheel keeps its rows in its group")
            return
        }
        let value = { (row: Int, property: MotionProperty, time: Double) -> Double in
            PropertyTrack(property, keyframes: placed[row].keyframes[property] ?? [])?.value(at: time) ?? .nan
        }
        let end = 0.5 + MoveExpansion.wheelDuration(rows: 2)
        // Before: the middle row in front, the next one down smaller, dimmer, lower and leaning its top towards the viewer
        #expect(abs(value(2, .positionY, 0)) < 1e-9 && abs(value(2, .scale, 0) - 1) < 1e-9 && abs(value(2, .opacity, 0) - 1) < 1e-9)
        #expect(value(3, .positionY, 0) > 0 && value(3, .positionY, 0) < 88 && value(3, .positionZ, 0) > 0)
        #expect(abs(value(3, .scale, 0) - DocumentExpansion.wheelSide) < 1e-9 && value(3, .rotationX, 0) < 0 && value(1, .rotationX, 0) > 0)
        #expect(value(3, .opacity, 0) < 0.5)
        // After: the last row in front
        #expect(abs(value(4, .positionY, end)) < 1e-6 && abs(value(4, .opacity, end) - 1) < 1e-6 && value(2, .positionY, end) < 0)
    }

    /// A wheel ticks once a row; a retext chimes once as its text arrives.
    @Test func aWheelTicksARowAndARetextChimes() async throws {
        let rows = (0..<6).map { index in
            #"{"id": "row\#(index)", "content": {"text": {"text": "Row \#(index)", "size": 40, "color": "ffffff"}}, "transform": {"position": [0, \#(index * 80), 0]}}"#
        }.joined(separator: ", ")
        let layers = #"[{"id": "menu", "content": {"group": [\#(rows)]}, "transform": {"position": [960, 300, 0]}, "moves": [{"move": "wheel", "start": 0.5, "intensity": 4}]}, "#
            + #"{"id": "status", "content": {"text": {"text": "Running", "size": 60, "color": "ffffff"}}, "transform": {"position": [960, 900, 0]}, "#
            + #""moves": [{"move": "retext", "start": 2, "words": ["Success"]}]}]"#
        var document = try document(layers)
        document.sound.style = .ambient
        let plan = await MotionPlan.build(document, bundle: bundle, shorterSide: 270, frameRate: 30)
        let cues = plan.sound.cues
        let ticks = cues.filter { $0.voice == .key(.letter) && $0.time > 0.5 && $0.time < 0.5 + MoveExpansion.wheelDuration(rows: 4) }
        #expect(ticks.count == 4)
        #expect(cues.contains { if case .blip = $0.voice { abs($0.time - 2 - MoveExpansion.retextLag) < 0.04 } else { false } })
    }

    /// A scene of parts shown and hidden at once, each in its own place, is named; one of contents swapping in place, or of things
    /// changing themselves, isn't.
    @Test func aSceneOfSwapsIsNamed() throws {
        let tiles = (0..<5).map { index in
            #"{"id": "tile\#(index)", "content": {"shape": {"size": [200, 120], "color": "333333"}}, "transform": {"position": [\#(300 + index * 300), 540, 0]}, "#
                + #""moves": [{"move": "show", "start": \#(0.2 + Double(index) * 0.3)}]}"#
        }.joined(separator: ", ")
        let swapped = try document("[\(tiles)]")
        #expect(MotionLint.findings(in: swapped).contains { $0.rule == .swaps })
        let pairs = (0..<5).map { index in
            #"{"id": "old\#(index)", "content": {"text": {"text": "Draft", "size": 40, "color": "ffffff"}}, "transform": {"position": [\#(300 + index * 300), 540, 0]}, "#
                + #""moves": [{"move": "hide", "start": 1}]}, {"id": "new\#(index)", "content": {"text": {"text": "Done", "size": 40, "color": "ffffff"}}, "#
                + #""transform": {"position": [\#(300 + index * 300), 540, 0]}, "moves": [{"move": "show", "start": 1}]}"#
        }.joined(separator: ", ")
        #expect(!MotionLint.findings(in: try document("[\(pairs)]")).contains { $0.rule == .swaps })
        let changing = try document(label(#"[{"move": "fadeUp"}, {"move": "retext", "start": 1, "words": ["Success"]}]"#))
        #expect(!MotionLint.findings(in: changing).contains { $0.rule == .swaps })
    }
}
