# Transitions made of the product

> After Cardinal (spec 0022) the user said the transitions are the same in every video and basic, and asked for films made
> personal to each product from its site. A film's turns are now made of the product's own things: the camera flies into its
> mark or the letters of its line (`through`), the frame turns over in a grid of its object (`motif`), and its control opens
> into the next scene (`by` on an expand or dive). The director names the product's mark, control, object and word while it
> researches, and builds its biggest turns from them.

## What was wrong

On 2026-10-12, about Cardinal: "currently we only have similar transitions for every video and they are also really basic and
animation is also basic … after researching about product seeing site make the video more personal to them".

Cardinal's 11 scenes used stack ×3, cut ×4, expand, cutOnMotion ×2 and a flow; Cardboard 6's used the same seams with a whip, a
dive and a ring. Its moves were pop ×39, morph ×21 and spin ×20. Every seam the director offered was generic. Its personality
table chose from the same expand, flow, whip and stack, so two products got the same transitions in different colours.

## The seams

A scene's `by` names a layer of the scene before (validated: a `through` or `motif` needs one, it must be in the scene before,
and only the seams below take it).

- **through** (1 s, `cubic-bezier(0.7, 0, 0.25, 1)`): the camera flies into the layer where it's thickest. The scene before is
  magnified log-evenly about that point, which comes to the frame's middle, until the shape covers the frame a tenth past. The
  next scene shows inside the shape from the start, fading in over the first 0.15. It comes up from 0.7 of its size out of a
  12 px blur. A quarter of the shape's thickness is left in its own colour round it (at most 12 px at 1080p). It sounds as a
  dive: air rising to its fastest, a landing.
- **motif** (0.9 s): the frame turns over in a grid of the layer, as it was at the cut. The cells are 160 px at 1080p, centred
  on where the layer was; the layer is 0.62 of a cell, and the wave crosses half the seam. Each copy pops out of nothing in
  its own colours (out-back, over 0.4 of its way), turning upright from 25°, neighbours opposite ways. It then grows on until
  it covers its cell. The next scene shows inside a copy that follows 0.16 behind and catches up as it grows; the scene before
  dims under them. It sounds as tiles.
- **by on expand, dive, iris, liquid, tiles**: they open out of the named layer instead of the last click.

### Where a shape is thickest

The pole is read once per plan from the layer's image coverage, 256 samples across its longer side, with a two-pass chamfer
distance. Among points within half a sample of the deepest, it takes the one nearest the middle. Flying into a word's middle
lands between two letters, into an "o" in its hole; flying into the pole ends with the shape filling the frame. For a group,
the pole is in its largest part on screen at the cut. Cardinal's rolling "30" is a word layer per number, and the first
("4") was the largest and long gone, so the flight stopped at 5× with the digits still round it.

An upward triangle's pole is its incentre, within 0.5 % of its height. Cardinal's "Agents live" has strokes 4.1 canvas px from
their middle to their edge, shown 2.5× larger, so the through ends 158× closer; "30" (300 px type) ends 77× closer.

## The director

Research names four things: the product's **mark**, **control**, **object** and **word**. Section 8 opens with what each
makes: through the mark, through the word, expand or dive by the control, flow of the object, a motif of many objects, and
through a card into what it holds. A film uses at least three, each made of a different thing, at its three biggest turns.
It has at least five kinds of seam and at most two stacks. The check asks: with the logo covered, could these transitions
belong to another product?

## Checked

`~/Movies/Reco/quality/product-seams/Cardinal seams.motion` is Cardinal with three seams changed:

- a motif of Priya's avatar into "Email the ones who fit.";
- a through by "Agents live" into "30 meetings booked";
- a through by "30" into the cards.

Seen frame by frame at 540p:

- The through reads as flying into the letters: half way, "meetings booked" shows inside "gents", then inside one stroke, then
  whole.
- Through "30", the cards show in the digits' strokes, then one stroke fills the frame.
- The avatar motif works but reads as polka dots: a plain circle isn't anyone's own shape. The director asks for the mark or
  an object drawn as the product draws it.

## Open

- The site's own motion (its CSS easings and durations) isn't read yet; personality is still chosen by eye.
- Nothing yet measures whether a film's transitions are made of its product; the director checks it by eye.
- The films from the app with these seams are in the roadmap row.
