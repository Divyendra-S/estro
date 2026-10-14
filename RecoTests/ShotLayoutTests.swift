//
//  ShotLayoutTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

/// What a Linear film made by the agent showed wrong, kept from coming back (2026-10-07): a tilted
/// hero, tall panels stacked into slivers, bare ground between features, a roll under its headline's
/// wipe, a closing cut short over a busy field.
struct ShotLayoutTests {

    /// The hero lies flat now, and tall panels go side by side: three 400×560 panels stacked came out
    /// 190 px wide in a Linear film (2026-10-07). Wide banners still stack.
    @Test func aHeroIsFlatAndTallPanelsCascadeSideBySide() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "assets": [{ "id": "panel", "url": "https://example.com", "selector": "#p" }, { "id": "banner", "url": "https://example.com", "selector": "#b" }],
          "scenes": [
            { "id": "hero", "duration": 3, "shot": { "shot": "uiHero", "ui": "panel" } },
            { "id": "tall", "duration": 2, "shot": { "shot": "uiCascade", "items": [{ "ui": "panel" }, { "ui": "panel" }, { "ui": "panel" }] } },
            { "id": "wide", "duration": 2, "shot": { "shot": "uiCascade", "items": [{ "ui": "banner" }, { "ui": "banner" }, { "ui": "banner" }] } }
          ]
        }
        """#.utf8))
        let scenes = DocumentExpansion.expanded(document, sizes: ["panel": CGSize(width: 400, height: 560), "banner": CGSize(width: 1200, height: 300)]).scenes
        #expect(scenes[0].layers[0].transform.rotation == [0, 0, 0])
        #expect(scenes[0].camera.keyframes[.focus] == nil)
        let rows = { (scene: MotionScene) -> [MotionLayer] in
            guard case .group(let rows) = scene.layers[0].content else { return [] }
            return rows
        }
        let tall = rows(scenes[1])
        #expect(tall.count == 3 && Set(tall.map { $0.transform.position[1] }).count == 1)
        #expect(tall.allSatisfy { width(of: $0) > 400 })
        let wide = rows(scenes[2])
        #expect(wide.count == 3 && Set(wide.map { $0.transform.position[0] }).count == 1)
    }

    /// Each feature comes in as the one before goes: 0.6 s of bare ground between a Linear film's
    /// Pulse and Documents showed only its field.
    @Test func aFeatureSequenceIsNeverBareBetweenItems() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "assets": [{ "id": "card", "url": "https://example.com", "selector": "#card" }],
          "scenes": [{ "id": "f", "duration": 4.4, "shot": { "shot": "featureSequence", "items": [{ "text": "Pulse", "ui": "card" }, { "text": "Docs", "ui": "card" }] } }]
        }
        """#.utf8))
        let layers = DocumentExpansion.expanded(document, sizes: ["card": CGSize(width: 784, height: 704)]).scenes[0].layers
        let move = { (id: String, kind: MotionMove.Kind) in layers.first { $0.id == id }?.moves.first { $0.kind == kind } }
        let leaving = try #require(move("f.ui0", .exit))
        let coming = try #require(move("f.ui1", .slideIn))
        #expect(try #require(coming.start) < (leaving.start ?? 0) + (leaving.duration ?? 0))
        #expect(try #require(move("f.index1", .fadeUp)?.start) < 2.2)
    }

    /// A roll set to start under its headline's wipe waits for it, and its words take turns; one that
    /// can't be read before its scene ends is found.
    @Test func aRollWaitsForItsHeadline() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "scenes": [{ "id": "t", "duration": 2.2, "shot": { "shot": "title", "text": "Delegate work to agents" },
                       "shotMoves": { "t.headline": [{ "move": "blurWipe" }, { "move": "roll", "start": 0.1, "duration": 0.9, "words": ["teams", "Linear"] }] } }]
        }
        """#.utf8))
        let scene = DocumentExpansion.expanded(document, sizes: [:]).scenes[0]
        guard case .group(let parts) = scene.layers[0].content else {
            Issue.record("Not a group")
            return
        }
        let wipe = 0.044 * Double("Delegate work to agents".count - 1) + 0.3
        let opacity = { (id: String) -> [Keyframe] in parts.first { $0.id == id }?.keyframes[MotionProperty.opacity] ?? [] }
        let leaving = try #require(opacity("t.headline.roll0").dropFirst().first?.time)
        let entering = try #require(opacity("t.headline.roll1").first?.time)
        #expect(leaving >= MoveExpansion.entranceStart + wipe + DocumentExpansion.rollReading - 1e-9)
        #expect(abs(entering - leaving - DocumentExpansion.rollHandover) < 1e-9)
        #expect(MotionLint.findings(in: document).contains { $0.rule == .rollLength })
    }

    /// A rolled count keeps the sign after its number.
    @Test func aRollKeepsWhatFollowsItsLastWord() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {"version": 1, "scenes": [{"id": "n", "duration": 3, "layers": [{"id": "count", "content": {"text": {"text": "98K+"}},
          "moves": [{"move": "roll", "start": 0.2, "words": ["210K+", "433K+"]}]}]}]}
        """#.utf8))
        let scene = DocumentExpansion.expanded(document, sizes: [:]).scenes[0]
        guard case .group(let parts) = scene.layers[0].content, case .group(let first) = parts.first?.content,
              case .text(let word) = first.first?.content else {
            Issue.record("Not a rolled group")
            return
        }
        #expect(word.text == "98K+")
    }

    @Test func aRollTurnsTheWholeNumber() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {"version": 1, "scenes": [{"id": "n", "duration": 3, "layers": [
          {"id": "checks", "content": {"text": {"text": "Checks 0/17"}}, "moves": [{"move": "roll", "start": 0.2, "words": ["4/17"]}]},
          {"id": "money", "content": {"text": {"text": "$0M"}}, "moves": [{"move": "roll", "start": 0.2, "words": ["9M"]}]}]}]}
        """#.utf8))
        let scene = DocumentExpansion.expanded(document, sizes: [:]).scenes[0]
        let texts = scene.layers.map { layer -> [String] in
            guard case .group(let parts) = layer.content else { return [] }
            return parts.map { part in
                if case .text(let text) = part.content { return text.text }
                if case .group(let inner) = part.content, case .text(let text) = inner.first?.content { return text.text }
                return ""
            }
        }
        // By words alone, "0/17" rolled its "17" into "4/17" and ended as "0/17/17"
        #expect(texts == [["Checks ", "0/17", "4/17"], ["$", "0M", "9M"]])
    }

    @Test func aRollShowsOneWordAtATime() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {"version": 1, "scenes": [{"id": "n", "duration": 3, "layers": [{"id": "count", "content": {"text": {"text": "0/17"}},
          "moves": [{"move": "roll", "start": 0.2, "words": ["4/17", "17/17"]}]}]}]}
        """#.utf8))
        let scene = DocumentExpansion.expanded(document, sizes: [:]).scenes[0]
        guard case .group(let parts) = scene.layers[0].content else {
            Issue.record("Not a rolled group")
            return
        }
        let opacities = parts.map { PropertyTrack(.opacity, keyframes: $0.keyframes[.opacity] ?? []) }
        // Laminar's checks counter read "0/4/1" mid-swap, the word leaving and the one coming both half there
        for frame in 0...360 {
            let seen = opacities.filter { ($0?.value(at: Double(frame) / 120) ?? 1) > 0.25 }
            #expect(seen.count <= 1, "frame \(frame)")
        }
    }

    @Test func aClosingIsDrawnOnBlackAndGivenItsLength() async throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1, "canvas": { "field": "matrix" },
          "scenes": [{ "id": "end", "duration": 3, "shot": { "shot": "closing", "text": "Linear", "items": [{ "text": "teams" }, { "text": "agents" }] } }]
        }
        """#.utf8))
        let rules = MotionLint.findings(in: document).map(\.rule)
        #expect(rules.contains(.endingLength) && !rules.contains(.busyField))
        #expect(abs(ShotLayout.closingLength(words: 2, hasLogo: false) - (0.25 + 0.42 + 0.74 + 1.4 + 0.3 + 1.2)) < 1e-9)
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        #expect(plan.scenes[0].field == .plain)
    }

    private func width(of layer: MotionLayer) -> Double {
        guard case .lifted(let content) = layer.content else { return 0 }
        return content.width ?? 0
    }
}
