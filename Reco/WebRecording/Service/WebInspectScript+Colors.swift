//
//  WebInspectScript+Colors.swift
//  Reco
//

extension WebInspectScript {

    /// The most colours listed, and the most SVG pictures read for theirs.
    static let maximumColors = 12
    static let maximumColorPictures = 12

    /// `colorsOf()` and `surfaceOf()`, for ``source`` (spec 0026).
    static let colorsFunction = #"""
    // The page's colours that aren't greys, wherever they're used: a trace's bars, a status, an error row, an SVG picture's own
    // fills. mastra.ai's palette by area was seven greys; its purple, green and orange bars were too small to count
    // A CSS colour as #rrggbb whatever its alpha (a translucent red row is still red), or #rrggbbaa with `withAlpha`; null when clear
    const shade = (color, withAlpha) => {
      swatch.clearRect(0, 0, 1, 1);
      swatch.fillStyle = color;
      swatch.fillRect(0, 0, 1, 1);
      const [red, green, blue, alpha] = swatch.getImageData(0, 0, 1, 1).data;
      if (alpha < 3) return null;
      const digits = (values) => values.map((value) => value.toString(16).padStart(2, '0')).join('');
      return '#' + digits([red, green, blue]) + (withAlpha && alpha < 250 ? digits([alpha]) : '');
    };
    const colorsOf = async () => {
      const found = new Map();
      const channels = (color) => [1, 3, 5].map((index) => parseInt(color.slice(index, index + 2), 16));
      const chroma = (color) => { const values = channels(color); return (Math.max(...values) - Math.min(...values)) / 255; };
      const labelOf = (element) => {
        for (let node = element, depth = 0; node && depth < 5; node = node.parentElement, depth++) {
          const text = (node.innerText || node.textContent || '').replace(/\s+/g, ' ').trim();
          if (text) return text.slice(0, 40);
        }
        return null;
      };
      const add = (color, used, label, area) => {
        if (!color || chroma(color) < 0.15) return;
        const entry = found.get(color) || { color, count: 0, area: 0, used: new Set(), near: new Set() };
        entry.count += 1;
        entry.area += Math.min(area, 40000);
        entry.used.add(used);
        if (label && entry.near.size < 3) entry.near.add(label);
        found.set(color, entry);
      };
      for (const element of document.querySelectorAll('body *')) {
        const box = element.getBoundingClientRect();
        if (box.width < 1 || box.height < 1 || !element.getClientRects().length) continue;
        const style = getComputedStyle(element);
        if (style.visibility === 'hidden' || style.opacity === '0') continue;
        const area = box.width * box.height;
        if (element instanceof SVGElement) {
          if (style.fill && style.fill !== 'none') add(shade(style.fill), 'fill', labelOf(element), area);
          if (style.stroke && style.stroke !== 'none') add(shade(style.stroke), 'line', labelOf(element), area);
          continue;
        }
        add(shade(style.backgroundColor), 'fill', labelOf(element), area);
        if ([...element.childNodes].some((node) => node.nodeType === 3 && node.textContent.trim())) add(shade(style.color), 'text', labelOf(element), area);
        if (parseFloat(style.borderTopWidth) > 0) add(shade(style.borderTopColor), 'line', labelOf(element), area);
        const stops = style.backgroundImage.includes('gradient(')
          ? style.backgroundImage.match(/(rgba?|hsla?|oklch|oklab|lab|lch|color)\([^)]*\)|#[0-9a-f]{3,8}\b/gi) || [] : [];
        for (const stop of stops) {
          add(shade(stop), 'gradient', labelOf(element), area);
        }
      }
      // A product's previews drawn in SVG carry its UI's colours in their own fills
      const drawings = [...document.querySelectorAll('img')].map((image) => image.currentSrc || image.src)
        .filter((address) => /\.svg(\?|$)/i.test(address)).slice(0, \#(maximumColorPictures));
      for (const address of [...new Set(drawings)]) {
        try {
          const svg = await (await fetch(address)).text();
          const name = 'picture ' + new URL(address).pathname.split('/').pop().replace(/\.[0-9a-z_-]{6,}\.svg$/i, '.svg');
          for (const match of svg.matchAll(/(fill|stroke|stop-color)\s*[:=]\s*["']?(#[0-9a-f]{3,8}\b|rgba?\([^)]*\))/gi)) add(shade(match[2]), 'picture', name, 400);
        } catch {}
      }
      // Near-duplicates (antialiased edges, a hover's shade) join the one used more
      const ranked = [...found.values()].sort((first, second) => (second.count + second.area / 20000) - (first.count + first.area / 20000));
      const kept = [];
      for (const entry of ranked) {
        const [red, green, blue] = channels(entry.color);
        const near = kept.find((other) => {
          const [r, g, b] = channels(other.color);
          return Math.hypot(r - red, g - green, b - blue) < 24;
        });
        if (near) {
          near.count += entry.count;
          entry.used.forEach((used) => near.used.add(used));
        } else {
          kept.push(entry);
        }
        if (kept.length === \#(maximumColors)) break;
      }
      return kept.map((entry) => ({ color: entry.color, used: [...entry.used], near: [...entry.near], count: entry.count }));
    };
    // How the page draws a panel: the fill, edge and corners most of its painted boxes share, translucent ones with their alpha
    const surfaceOf = () => {
      const counts = new Map();
      for (const element of document.querySelectorAll('body *')) {
        const box = element.getBoundingClientRect();
        if (box.width < 160 || box.height < 80 || box.width > innerWidth * 0.96 || !isVisible(element)) continue;
        const style = getComputedStyle(element);
        const radius = parseFloat(style.borderTopLeftRadius) || 0;
        const width = parseFloat(style.borderTopWidth) || 0;
        const background = shade(style.backgroundColor, true);
        const edge = width > 0 ? shade(style.borderTopColor, true) : null;
        if (radius <= 0 || (!background && !edge)) continue;
        const surface = { background: background ?? undefined, border: edge ? `${width}px ${edge}` : undefined, radius };
        const key = JSON.stringify(surface);
        counts.set(key, { surface, count: (counts.get(key)?.count || 0) + 1 });
      }
      return [...counts.values()].sort((first, second) => second.count - first.count)[0]?.surface;
    };
    """#
}
