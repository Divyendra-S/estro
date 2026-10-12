//
//  WebInspectScript+Pictures.swift
//  Reco
//

extension WebInspectScript {

    /// The most pictures listed, shown ones first, then the largest.
    static let maximumPictures = 40

    /// `picturesOf()`, for ``source`` (spec 0024).
    static let picturesFunction = #"""
    // Every picture by its address, shown or not (a tab's, a carousel's): the product's own screenshots and previews, at
    // least 200×120 of its own pixels (avatars and icons aren't), once each. A Next.js resized copy is named by its original,
    // which is sharper
    const picturesOf = () => {
      const found = new Map();
      const add = (element, address, kind, width, height, poster) => {
        if (!address || address.startsWith('data:') || width < 200 || height < 120) return;
        let url = new URL(address, location.href);
        const original = url.pathname.endsWith('/_next/image') && url.searchParams.get('url');
        if (original) url = new URL(original, location.href);
        if (found.has(url.href)) return;
        const alt = (element.getAttribute('alt') || element.getAttribute('aria-label') || '').trim().slice(0, 120);
        found.set(url.href, {
          url: url.href.slice(0, 500), kind, alt: alt || undefined, size: { width, height },
          poster: poster || undefined, shown: isVisible(element)
        });
      };
      for (const image of document.querySelectorAll('img')) {
        add(image, image.currentSrc || image.src, 'img', image.naturalWidth || image.width, image.naturalHeight || image.height);
      }
      for (const video of document.querySelectorAll('video')) {
        const source = video.currentSrc || video.src || video.querySelector('source')?.src;
        add(video, source, 'video', video.videoWidth || video.clientWidth, video.videoHeight || video.clientHeight, video.poster);
      }
      return [...found.values()].sort((first, second) => (second.shown - first.shown) ||
        second.size.width * second.size.height - first.size.width * first.size.height).slice(0, \#(maximumPictures));
    };
    """#
}
