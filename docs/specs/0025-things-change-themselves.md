# Things change themselves

> The user's verdict on Mastra 3 (spec 0024): "This time it took UI from the URL … That was good. But animations and those
> things were not that good. There were really not much of animations there, only one or two I seen." They sent four launch
> clips in one video as the bar for motion (not to copy). In those clips every change is the thing itself turning into its
> next state. Mastra 3 swapped parts in and out. Films now have moves for UI changing state, a glass lens seam, and a lint
> finding for scenes that are cut inside themselves.

## The reference, measured

`~/Movies/Reco/references/x-four/four.mp4`: a 2×2 grid of four 5 s clips, 30 fps (sheets `q-*.png`, `tl-spin.png`,
`tl-morph.png`, `tr-lens.png`).

| Clip | What changes, and how |
|---|---|
| A product menu, dark | The list spins on a drum to a new row: about six rows in 0.55 s, blurred through its middle, the rows above and below smaller, dimmer and curving away. A light sweeps the chosen pill. Its label turns into "Create Agent" letter by letter: the old letters go out of order in 0.23 s, and the new ones arrive 0.12 s later, spaced out and closing up over 0.45 s. The pill squashes into a bar, the bar thins into a line, and icons pop up out of the line into a toolbar. One icon opens its label. |
| A TV on a hill | "GPT 5.6" decodes. A disc of glass opens out of the TV onto the next scene: a sixth of the width 0.03 s in, past the corners by 0.3 s, out-expo. Its edge is frosted, with a sharp hairline of light, and the scene inside settles from closer. A card's reply streams in, its newest words lit. |
| A misty field | The prompt card rises through a soft vertical mask, then is typed into. A fog rising from the bottom takes the frame. |
| A wordmark | The wordmark's letters turn one by one into the products, which spin in 3D, then back. |

None of the clips swaps a part in or out at once.

## What was wrong

Mastra 3 made 61 of its 114 moves `show` and `hide`:
- the opening's files and errors appeared and went one at a time;
- the eval rows swapped their values.

The director's action table taught this: "steps or rows ticking to done (`show`/`hide` swaps …)". The engine had no move
for a label becoming another, or for a list turning to its choice.

## The change

- **`retext`** (text): `{"move": "retext", "start": 1, "words": ["Success"]}`.
  - The text becomes a group of its states at the same anchor.
  - The old state `dissolve`s while the next `decode`s over it, `retextLag` (0.12 s) later.
  - Each state is there (opacity) only from its decode to its dissolve's end, so the checks see what is drawn.
  - A later retext turns it again. Its reveal stays on its first state, and its other moves stay on the group.
- **`decode` and `dissolve`** (text):
  - Characters come or go out of order (`TextReveal.scrambled`): in order, but each up to 2.5 characters late, the same
    for the same text every time.
  - Each character sharpens from 8 % of its line as it fades.
  - A decode starts spread to 1.35× about the layer's anchor and closes up over its time plus 0.2 s.
  - A dissolve goes into the plan layer's new `exit`, so it follows the layer's own reveal.
- **`wheel`** (a group of rows): `{"move": "wheel", "intensity": 4}`.
  - The rows sit on a drum about the group's place, two rows round (`DrumPose`). Each leans away and moves back, down to
    0.8× size and 0.4 opacity a row from the front, and is gone past 77°.
  - The wheel turns `intensity` rows on the move curve, sampled at 60 Hz as keyframes, so the rows blur through motion
    blur as they pass.
  - Sound: a tick as each row passes the front, and a whoosh for three rows or more.
- **`lens`** (a graphic seam, 0.65 s, `by` or the last click):
  - A disc opens out-expo onto the next scene. The next scene settles from 1.25×; the one before is pushed 4 % closer.
  - The disc's frosted band is a tenth of its radius (at most 120 px at 1080p) and clears from 0.35 to 0.8 of the way.
  - It has a hairline of light and is drawn without motion blur.
- **The `swaps` lint:** a scene is named when at least four of its moves, and at least half of all its moves, show or hide
  a part at once in a place of its own. A part shown or hidden where another part is counts as a swap of contents and is not
  named: Lovable's bento on a beat, ElevenLabs' pictures under words.
- **The director** (sections 7 and 8, the check): things change, never swap.
  - The action table names `retext`, `wheel` and `decode`.
  - A detail opens by `through` or `lens`.
  - The story recipes' pressed label and bento statuses `retext`.

## Checked

- `UIStateMoveTests`:
  - scrambled order and timing;
  - a retext's states, their opacity, and that both are drawn round the same middle;
  - a decode's letters spread past their box and close up;
  - the drum's poses before and after a turn;
  - the wheel's ticks and the retext's chime;
  - the swaps lint on scattered shows, not on swaps in place.
- `GraphicSeamTests` cover the lens: it starts on the scene before and ends on the next. Half way it is checked at a fifth
  of the way instead, since it opens out-expo.
- Look-dev at 1080p, frames checked by eye:
  - a model pill retexting "openai/gpt-4o" into "anthropic/claude-sonnet-4-5" as it morphs wider;
  - a menu of seven models wheeling four rows;
  - a lens onto "Success · 10.364s".
  - The lens first read as a grey ring 60 px wide: the fast rim smeared by motion blur, and too much frost. Drawn sharp with
    thinner frost, it reads as the reference's glass.
- The whole suite: 951 tests. Only `keepsATransparentBackgroundInProRes4444` fails, as before.

## Mastra 4

From the app, with the same neutral prompt (22 min, 20.1 s at 4K60, `~/Desktop/Mastra v4.mp4`). Its document has no `show` or
`hide`: 24 morphs, 8 retexts and 6 typings, joined by flow, expand, `lens`, `through` and unfold seams. The story:
1. The weather agent's code is typed.
2. "Will it rain in Tokyo tomorrow?" is typed into its chat and sent.
3. The send expands into the landing's trace: its bars grow, and Running turns into its timings by `retext`.
4. The tool row is clicked and a lens opens from it onto the tool call: "Tokyo" in, "Rain showers" out, Success.
5. "Evaluate changes before and after shipping." is shown, and the film goes through its letters into the evals, 2/4
   turning into 4/4 passed.
6. The wordmark unfolds.

It was still 39 % of the time: the statement held about 2 s and the end card 2.5 s. The `through` into the evals swept a
blurred white letter ring the size of the frame across it for about 0.4 s. It used no `wheel`.

## Open

- The wordmark's letters turning into objects, a card rising through a soft mask, and a fog rising over the frame are not
  built.
- A pill's label sliding out inside it (clipped by the pill) needs groups that clip.
