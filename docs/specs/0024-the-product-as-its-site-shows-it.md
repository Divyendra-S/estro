# The product as its site shows it

> The user's verdict on Mastra (spec 0023's first film): "really bad … repeated, no UI or assets taken from their website …
> animations pretty generic and repetitive"; Cardboard is the best so far. Films are now made of the site's own pictures of
> the product. `inspect_page` lists every picture by its address, and the director lifts them and shows dense ones close,
> part by part. It also names the arc every recent film took, so a film doesn't repeat it.

## What was wrong

- **No UI.** mastra.ai shows its product in ten vector previews: Studio's agent chat, traces, workflows, memory, server,
  evals, metrics and datasets, most of them in tabs. It also has 14 code blocks and two case-study videos with posters. The
  film lifted only the logo and four integration marks. Its agent card, chat and trace were drawn from shapes, because the
  director said "the product's parts are rebuilt as shapes, type and its own images" and "never a dense panel". That rule
  came from the Orca films, where lifted panes ran off the frame.
- **Cardboard was its pictures.** Cardboard 6, the README's film, lifted 18 pictures from cardboard.ai: its outputs,
  storyboards and showcase. The rule didn't hurt Cardboard only because its site's pictures are photos, not screens.
- **One arc.** Tasklet, Cardboard 6 and Mastra ran:
  1. the ask typed big;
  2. the box;
  3. the send expanding into "Working…";
  4. the answer popping in;
  5. three words one at a time;
  6. the ring into the logo.

  The scene ids repeat (`ask`, `box`, `work`, `end`). The director's tables gave one answer each for the ask, the working,
  the answer and the end (`ring`), and step 10 loaded `reco-story-film` for every film.

## The change

- **`inspect_page` `pictures`** lists every `img` and `video` on the page, shown or not (another tab's, a slide's).
  - Each entry has its absolute address, kind, alt, its own size, a video's poster and whether it was shown.
  - Only pictures at least 200×120 of their own pixels are listed, so avatars and icons are left out. Each is listed once,
    shown ones first, then the largest, at most 40.
  - A Next.js resized copy (`/_next/image?url=…`) is named by its original, which is sharper and has the extension an image
    lift needs (`WebPageRenderer.imagePage`).
  - An `img` that hasn't loaded is measured by its attributes (`width` and `height`).
- **The director**:
  - Research lists the product's pictures of itself.
  - Section 9 makes the film of them:
    - lifted by address, with `viewport` at their own size;
    - a dense one shown close, one part at a time (`macro` views, or `region` assets of the one picture arriving in the
      order the product makes them);
    - shapes only for what the site doesn't picture.
  - Section 7 names the template arc and allows at most two of its beats.
  - The end into the logo comes from the variation (flow into the mark, unfold, letters on a cut, ring), not always `ring`.
  - Step 10 loads the technique skills the actions need, `reco-launch-film` for real UI in macro.

## Checked

- `WebCleanPageTests.inspectingListsEveryPictureByItsAddress`: a shown picture, a hidden tab's Next.js copy by its
  original, a video with its poster; no avatar and no duplicate.
- `Mastra 2` from the app, with the same neutral prompt (14 min, 18 s at 4K60, `~/Desktop/Mastra v2.mp4`). It lifted:
  - the site's own `agent.ts` code panel (on glass);
  - Studio's memory timeline and evals table, from their SVG previews, sharp at 8–9×;
  - the wordmark.

  The arc is new: `new Agent()` typed, a `through` into the code, a `weather-agent` pill carried by `flow` across the memory
  and the evals ("reasons, acts, remembers, improves"), and the wordmark `unfold`ed. It has no "Working…" beat and no ring.
  Most of its motion is still scrolling across the previews.

## Mastra 2's verdict, and the second change

> "the new video also did not have anything from their website … same ole video shader … no story nothing really bad
> cardboard one was really good we took ui also from the landings ui and transition also were according to their product"

Against Cardboard 6, frame by frame and document by document:

| | Cardboard 6 | Mastra 2 |
|---|---|---|
| Product | The landing's own prompt, its working steps in its words, clips, timeline, reframe, rebuilt as layers | Three flat grey previews scrolled across, and a code panel |
| Pictures | 18 of the site's photos | none but the previews |
| Story | A request, the product working, the film made | A feature tour: code, memory, evals, the logo |
| Ground | `pool` in its blue | A new dither each scene (matrix, warp, tide, swirl) |
| Scenes | 13 in 33 s | 6 in 18 s |

- **Pointing at `pictures` made a film of screenshots.** mastra.ai's hero draws its product as live HTML: an `ops-agent`
  trace with its timings, evals scores (+24 %, 98.2 %), a file tree. The agent took three tab previews instead.
- **Banning the arc removed the story** and put nothing in its place.
- **Dither was every developer tool's ground.** The director's, the story skill's and the launch skill's looks tables all
  sent technical brands to dither, and the launch skill gave every scene after a whip a new field.

The change:

- **Research** reads the landing's product UI with every word and number on it, and the site's own example job.
- **The brief** has a story: who, the job, how it ends.
- **The landing's UI is rebuilt as layers**, so it acts as the product does. Pictures are lifted into its slots, and a
  preview is never the action. A generic box, "Working…" and three words are used only where the site has nothing of its
  own for that beat.
- **The ground is the site's own.** A dark site whose colour is in its UI gets `pool`; dither only where the site's own
  pictures have dots or pixels. One field a film.

`Mastra 3` from the app, the same prompt (19 min, 27.9 s at 4K60, `~/Desktop/Mastra v3.mp4`):

- **A story.** "My agent was all glue code." is typed over a pile of files with red errors, then "No idea why it failed" is
  eaten. The name and a line follow, then the weather agent's code typed in, and its run.
- **The landing's trace rebuilt as layers,** in its own labels ("agent run", "input processor: message-history", "llm",
  "step", "chunk: 'tool-call'"). Its bars grow and "Running…" turns to Success. It expands into the tool call's input and
  output, and the evals rows tick to 1.0.
- **No previews scrolled.** One field (`satin`).
- **Still 26 % of the time.** Its end card holds still for 4.0 s, and the statement for 1.2 s. Its line ("Agents that
  reason, remember, and act.") is the agent's, not the site's.

## Open

- The site's pictures are flat images. A preview's parts (a trace's rows, a chat's bubbles) move only as `region` crops of
  it, not as the product's own elements.
- Nothing measures whether a film's product moments are its site's pictures; the director checks by eye.
