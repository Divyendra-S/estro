//
//  WebPageRenderer+Inspect.swift
//  Reco
//

import CoreGraphics
import WebKit

// MARK: - Inspecting

extension WebPageRenderer {

    /// Loads the script's page and lists what it shows at scroll 0: see ``WebInspectScript``.
    /// `selectors` are the ones to also return the box of.
    func inspect(selectors: [String]) async throws -> PageInspection {
        try await inspect(selectors: selectors, looking: false).inspection
    }

    /// The same, and with `looking` the page from its top to its foot as one picture (``look(of:in:)``): an agent read a site
    /// only as text and filmed mastra.ai, a black page of purple, green and orange bars, on grey satin under a green line it
    /// made up (spec 0026).
    func inspect(selectors: [String], looking: Bool) async throws -> (inspection: PageInspection, look: CGImage?) {
        // Settled in real time, as in a take: the page's own scripts finish drawing before it's read
        try await withLoadedPage { webView in
            let result = try await webView.callAsyncJavaScript(
                WebInspectScript.source, arguments: ["selectors": selectors], contentWorld: .defaultClient
            )
            guard let json = result as? String else { throw WebRenderError.loadFailed("The page couldn't be read.") }
            var inspection = try JSONDecoder().decode(PageInspection.self, from: Data(json.utf8))
            inspection.renderCost = try await renderCost()
            return (inspection, looking ? try? await look(of: inspection, in: webView) : nil)
        }
    }

    /// Seconds of rendering per second of video at scale 1 and 2, from one snapshot of the page at
    /// each: the snapshot is the cost of a frame, 14 ms on a simple page and 310 ms on linear.app at
    /// 2× (M5), the rest of a frame a few ms. Lets an agent choose a scale the run's time allows.
    private func renderCost() async throws -> [String: Double] {
        var cost: [String: Double] = [:]
        for scale in [1, 2] {
            let start = ContinuousClock.now
            _ = try await snapshot(scale: scale)
            let seconds = (ContinuousClock.now - start) / .seconds(1)
            cost[String(scale)] = (seconds * Double(WebScript.frameRate) * 100).rounded() / 100
        }
        return cost
    }

    /// The page screen by screen, at most ``lookScreens`` spread evenly from its top to its foot, in a sheet of
    /// ``ContactSheet/columns`` across, each ``lookTileWidth`` pixels wide; back at its top after.
    private func look(of inspection: PageInspection, in webView: WKWebView) async throws -> CGImage? {
        let screen = inspection.viewport.height
        let screens = min(max(Int((inspection.pageHeight / max(screen, 1)).rounded(.up)), 1), Self.lookScreens)
        let span = max(inspection.pageHeight - screen, 0)
        var tiles: [CGImage] = []
        for index in 0..<screens {
            let top = screens > 1 ? span * Double(index) / Double(screens - 1) : 0
            _ = try await webView.callAsyncJavaScript("scrollTo({ left: 0, top, behavior: 'instant' })", arguments: ["top": top], contentWorld: .defaultClient)
            // What reveals itself as it scrolls in has come in
            try await Task.sleep(for: Self.lookSettle)
            if let tile = Self.scaled(try await snapshot(scale: 1), toWidth: Self.lookTileWidth) {
                tiles.append(tile)
            }
        }
        _ = try? await webView.callAsyncJavaScript("scrollTo({ left: 0, top: 0, behavior: 'instant' })", arguments: [:], contentWorld: .defaultClient)
        return ContactSheet.sheet(of: tiles)
    }

    /// `image` drawn `width` pixels wide, its shape kept.
    private static func scaled(_ image: CGImage, toWidth width: Int) -> CGImage? {
        let height = Int((Double(image.height) * Double(width) / Double(max(image.width, 1))).rounded())
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Nine screens, three across at 640 px: mastra.ai's ten screens in a 1936 × 1216 sheet, about 1,600 tokens to an agent;
    /// each screen waits 0.3 s after it's scrolled to.
    static let lookScreens = 9
    static let lookTileWidth = 640
    static let lookSettle = Duration.milliseconds(300)
}
