# The site's kit, seen sharp

> The user's verdict on Mastra 4 (spec 0025): "We can scrape and take more things from the website and use them, their
> gradients, their theme, their everything which is on the website. And somewhere the animation, zoom animation, sometime
> got blurry. There was a green line which was everywhere that was not looking good because it was repeating itself …
> Still not there yet."

## What was wrong, measured

- **Blurry zooms.** Three seams magnified a frame that was already drawn.
  - `through` enlarged the scene before up to 60 times, into a letter's stroke, under a 12 px defocus. At 14.45 s the
    statement's letters were a smear with coloured fringes.
  - `expand` grew the next scene out of the send button. Averaged across the shutter (96 samples), the trace inside it was
    a radial blur.
  - `dive` was built the same way as `through`.
- **The grey slab.** The expand's rectangle turned from the control's colour to the average of the next frame over
  0.1–0.55 of the way. Mastra's white send button became a mid-grey rectangle for a fifth of a second.
- **The green line.** One shape, `obj`, a green bar 6–12 px tall, drew itself under the code, the chat tab, the statement,
  the eval score and the logo: five of the seven scenes.
- **Nothing from the site's look.** The agent had the site only as text.
  - `palette` is ranked by area, and gave seven greys (`#0a0a0a` … `#939393`). mastra.ai's purple, green and orange trace
    bars, its red failing rows and its orange banner were too small to count.
  - No `accent` was found, so the agent chose green and painted everything green.
  - It put the film on `satin`: Raycast's grey cloth, which the story skill's table offered for "dark, its colour all in
    its UI". mastra.ai itself is flat black, with notched panels.

## The change

- **`inspect_page` shows the site.**
  - It scrolls the page top to foot: at most nine screens, spread evenly, each after 0.3 s.
  - The screens come back as one JPEG in the tool's reply, three across at 640 px. mastra.ai's sheet is 1936 × 1216.
  - The agent sees the ground, the panels and the colours before it writes anything.
- **`brand.colors`**: every colour that isn't a grey (chroma ≥ 0.15), however small, most used first, at most 12.
  - Read from fills, text, borders, SVG fills and strokes, gradient stops, and the fills inside the page's SVG pictures
    (fetched, at most 12).
  - Each colour comes with how it's `used` and the words `near` it. Translucent colours keep their hue.
- **`brand.surface`**: the fill, border and corners most of the page's painted panels share. A translucent fill or border
  keeps its alpha (`#ffffff0a`, `1px #ffffff1a`).
- **Zooms drawn sharp.**
  - A `through` or `dive` draws the scene before again through the seam's magnified view (`seamView`): every layer is
    resampled from its own image, not from the frame.
  - Text shown past its raster scale is `crisped`: its alpha is cut at half its solid value, over about a pixel, so a
    letter's edge stays sharp at any magnification.
  - The through's window (the eroded shape) is crisped the same way.
  - `expand`, `dive` and `through` are drawn at the frame's own time, with no shutter average. Their 12–14 px defocus of
    the next scene is gone.
- **The expand's colour.** The rectangle turns to the next scene's ground (its field), not its frame's average, over
  0.05–0.3 of the way. The next scene comes up over 0.15–0.5, and the control is gone by 0.25.
- **The `ornament` lint.** It names a thin line of one colour drawn on its own (not in a group) in three scenes or more. A
  line here is at most 1.2 % of the canvas's shorter side thick, at its own size or after a morph.
- **The director.**
  - Research begins by looking at the site's picture and writing down its kit: ground, surfaces, colours by what they're
    on, and signature pieces.
  - Each colour is painted on what the site paints it on, never one colour on everything.
  - New rule, **No ornament**.
  - The story and launch skills no longer send a dark site to `satin`: they send it to `pool` in its hue, or `plain` on
    its background with its panels lit.

## Mastra 5, and what it still showed

From the app with the same neutral prompt (30 min with its export, 22.6 s at 4K60):
- **The film.**
  - It stands on `pool` in mastra.ai's green: black, as the site is, with no satin.
  - It paints the trace's bars purple, green and orange as the site does, and the failing eval rows red.
  - It types its agent's code and asks the chat for Rome's weather. The mastra mark thinks, and a `through` by the mark
    opens on the trace running. The reply comes back.
  - It opens the evals from the Evaluate tab: 62 % turns to 98.2 %.
  - It ends on the site's own line, "**Build**, observe, and improve agents that run for days.", with "Build" in green, then
    the wordmark.
  - It draws no repeated line, and is still 27 % of the time (Mastra 4: 39 %).
- **Its frames still showed three blurs.**
  - **The mark's rim** went soft at the through's peak: the mark is a lift tinted white, and only text was crisped.
  - **A camera move:** a 2× zoom-pan in 0.55 s (3.75 frame widths a second) smeared the eval table's words about 60 px at 1080p.
  - **The flow seam:** its handoff blurred what left 8 px and what came 10 px, and code went out under the chat as a smear.

Fixed in the engine (the document unchanged):
- **Tinted lifts** (`tint`, a mark in one colour) are crisped as text is (`solidAlpha`, the tint's alpha).
- **Motion blur below whip speed is held to 1.2 % of the frame's height** (13 px at 1080p).
  - It grows to the whole travel between 4 and 5 frame widths a second (`SoundRules.whipSpeed`), so a whip still streaks.
  - The samples span that share of the shutter. Fewer samples across the whole shutter only stepped the blur.
- **Travel is measured with corners held inside the frame.** Zoomed, a panel's corners off screen swept faster than
  anything seen.
- **A flow slides and fades sharp.**
  - Its offsets spread over at most 0.15 s: twelve lines of code, 0.045 s apart, would have left over half a second.
  - The scene before is gone 0.07 s after the cut, as the next scene's first layers come.

## Checked

- `SiteKitTests`:
  - A dark page's 6 px purple bar, green status and translucent red row are its colours, each with the words near it,
    and no grey is listed. Its panels' surface is `#ffffff0a`, `1px #ffffff1a`, 24.
  - Looking returns three screens of a three-screen page, red, green and blue, in one sheet.
  - Half way through a `through` into a 700 px "O" (magnified over 6×), the middle row has at most 12 pixels that are
    neither the letter, the ground nor the next scene.
  - An expand from a white control into a blue scene with a white card is blue round the card at 0.32 of the way.
  - A green line in three scenes is named; in two, or inside a group, it isn't.
  - A pan at 3.75 widths a second blurs 13 px at 1080p; one at 8 its whole travel.
  - Twelve lines flowing out leave within 0.15 s, and nothing in a flow blurs.
  - A tinted mark and a translucent text get their solid alpha.
- Mastra 4's own document through the new engine at 1080p: the expand opens dark with the trace sharp inside it, and the
  `through` letters keep sharp outlines as they grow.
- Mastra 5's document through the engine after the second round: the mark's rim is sharp on both sides, and the eval table
  reads through the camera's zoom-pan.
- Re-exported by the app's `export_recording` with the second round (4K60, `~/Desktop/Mastra v5.mp4`), its turns are sharp:
  - the code clears before the chat arrives, and the trace before the reply;
  - the mark's rim is sharp, and the evals read under the camera.
  - It is still 25 % of the time: the end card holds about 2 s.
- The whole suite: 959 tests. Only `keepsATransparentBackgroundInProRes4444` fails, as before.

## Open

- Shapes (panels) magnified past their raster still soften at their edges; only text is crisped.
- The look sheet is for the agent to see. The film doesn't yet lift the site's own backgrounds (a hero's glow, a grid) as
  a ground.
