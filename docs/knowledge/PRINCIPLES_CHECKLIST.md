# Principles Checklist

v1.5 · 2026-09-28 · 27 lines for the 23 principles in `DESIGN_PRINCIPLES.md`: every principle
gets a line, P-19 gets four, because its contrast table, its rule for text on a verdict fill, its
focus ring and its rule for color on a block are checked separately, and P-15 gets two, because
gating an animation and keeping a blanket reset off a substitution are different mistakes. Nothing
here is a principle the other document lacks.

## Product

- [ ] P-01 — The screenshot is the largest thing on screen and is fitted, never cropped.
- [ ] P-02 — Every verdict carries direction, glyph, word and hue; nothing is color-only.
- [ ] P-03 — One queue, newest unreviewed first; undo is one step on one control.
- [ ] P-04 — Reversible actions commit silently; irreversible ones go through the iOS dialog.

## Visual

- [ ] P-05 — Light only; every token is one fixed OKLCH value; canvas and surface are pure white.
- [ ] P-06 — Saturation appears only on verdicts (stamps, the three verdict buttons, the Trash count badge, the destructive fill) and on full-bleed blocks.
- [ ] P-07 — Text, icons, primary fill and shadows are navy; black appears only in the viewer.
- [ ] P-08 — Figures are typeset: a face is round parentheses from the display face plus one world-script glyph, seven faces for seven blocks, no glyph twice; there are no illustration assets.
- [ ] P-09 — No borders except the focus ring; shadows only on things that float.
- [ ] P-10 — Radius matches inner padding; nested radius is outer minus gap, clamped up to `DSRadius.xs` (6) and still smaller than the outer; corners are continuous.

## Code

- [ ] P-11 — Types are `DS*`, the two deliberate exceptions being `Brand` and `VerdictColorSet`; in Swift the product name appears only in `Brand.swift`, and no token or CSS variable carries it.
- [ ] P-12 — No hex, point, duration or spring literal outside `Sift/DesignSystem/`.
- [ ] P-13 — Type, shadow, haptics and focus go through `.dsType` / `.dsShadow` / `.dsHaptic` / `.dsFocusRing(_:cornerRadius:color:)`, whose color parameter takes a token and defaults to `DSColor.focus`.
- [ ] P-14 — Icons are drawn from `DSIconRef.image`, never `Image(systemName:)`.
- [ ] P-15 — Every animation is created through `DSMotion.gated(_:reduce:)`, or `gated(_:reduce:reduced:)` with a named substitute (`snapBackReduced`, `crossFade`); no raw curve at a call site.
- [ ] P-15 — Reduce Motion substitutes where something still has to happen, and any blanket `!important` reset excludes whatever implements a substitution (the guide excludes the deck through `:not(:where(.deck__card, .deck__card *))`); `revert-layer` is not that exclusion, because with no cascade layers it rolls back to 0 s.
- [ ] P-16 — The root view pins `preferredColorScheme(.light)`; nothing reads `colorScheme`.

## Patterns

- [ ] P-17 — Screens use components, components use tokens; no level is skipped.
- [ ] P-18 — Component state is an enum and every case — loading, empty, error, disabled — is designed.

## Accessibility

- [ ] P-19 — Contrast passes the generated table, all 43 pairs; the only exemptions are the three informational rows.
- [ ] P-19 — On a verdict `main` fill, only the 32 pt stamp word and the icon glyphs use `on` at 3:1; every smaller label, the 16 pt bold destructive one included, is `ink` (4.61 on tomato, 10.20 on yellow). Cobalt is the one exception: white on `archive.main` measures 6.57 and clears 4.5 on its own, so a white label on cobalt is legal at label size.
- [ ] P-19 — The focus ring is `ink` at 60 % and 3 pt, and its two rows measure 4.34 over `canvas` and 4.06 over `surfaceRaised`. The helper takes the ring color, `DSColor.focus` by default, because the ring is translucent and its ratio depends on what it sits on.
- [ ] P-19 — On a color block, color comes from `DSBlock`: the CTA pill is `ctaFill` (the block's ink) with `ctaLabel` (its counterpart), and the focus ring is `focusRing` (the block's ink at full strength, never `DSColor.focus`, which composites to 2.65 on tomato, 2.92 on lavender and 1.71 on violet). Exactly one filled action per block: a second action is bare text in the block's ink, because a filled secondary is a shape owing 3:1 against all seven fills and `surfaceRaised` clears that bar on one of them only, `violet` at 5.74.
- [ ] P-20 — Ten of the eleven roles bind through `relativeTo:`; `stamp` binds to no text style, is scaled at the call site and clamped to 44 pt by `stampFont(size:)`, which returns a fixed-size font; layouts wrap instead of truncating.
- [ ] P-21 — Every interactive element is at least `DSSize.tapMin`; pad the hit area, not the glyph.
- [ ] P-22 — Card is one element; custom actions are Trash, Archive, Favorite, Rewind last; commits announce.

## Verification

- [ ] P-23 — All four commands run and their output pasted; no claim of completion without it.

## Before you ship a screen

- [ ] Every state in the component's enum is rendered, including loading, empty and error.
- [ ] No literal value anywhere in the screen file.
- [ ] Every color used appears in the generated token table.
- [ ] Every interactive element is at least 44 pt in both dimensions.
- [ ] Type roles come from `DSTextRole`; `caption` is not used above `body`.
- [ ] Nothing new has a border; any new shadow belongs to something that actually floats.
- [ ] Every animation goes through `DSMotion.gated(_:reduce:)` or `gated(_:reduce:reduced:)`, and the screen is checked with Reduce Motion on.
- [ ] Any text sitting on a verdict `main` fill is `ink`, unless it is the 32 pt stamp word, an icon glyph, or a white label on cobalt (6.57).
- [ ] Anything on a color block takes its color from `DSBlock`: `ink` for copy, `ctaFill` / `ctaLabel` for the CTA pill, `focusRing` for the ring. No white pill, no `DSColor.focus`.
- [ ] The block has one filled action and no more; any second action on it is bare text in the block's ink, never a filled secondary.
- [ ] The screen is checked at the largest accessibility text size; nothing truncates, and a stamp stops growing at 44 pt.
- [ ] VoiceOver: labels, custom action order, announcement after a commit, decoration hidden.
- [ ] Any destructive control names a count and uses the word "permanently" only when it means it.
- [ ] Copy leads with a verb; playful wording appears only in titles and empty states.
- [ ] All four commands were run and their output pasted: `contrast` at `43 pairs · 0 failure(s)`, `emit-css` regenerated and its `:root` block pasted into `design-system.html`, `lint` ending in `lint: OK`, `typecheck: OK`.

## Commands

Four commands, every time. The same four appear in `README.md`, in P-23 and in the guide's checklist
section.

```
python3 scripts/ds_tokens.py contrast                           # 43 pairs · 0 failure(s), no gamut warning
python3 scripts/ds_tokens.py emit-css > scripts/out/tokens.css  # paste the :root block into design-system.html
python3 scripts/ds_tokens.py lint                               # last line: lint: OK
scripts/typecheck-ds.sh                                         # typecheck: OK
```

`lint` also prints one `lint: EXCEPTION` line per `DECLARATION_ONLY` entry in
`scripts/ds_tokens.py` and, until the Noun Project credits land, one `lint: WARNING` line. Those are
expected output, not failures — the verdict is the last line (ADR-022). The EXCEPTION lines are the
`DECLARATION_ONLY` entries printing themselves with their recorded reason, and the WARNING for an
empty `DSIconCredits.entries` does not change the exit code. Usage behind those checks is counted by
exact variable name outside HTML comments, so a variable named only inside `<!-- ... -->` counts as
unused and `--color-ink` is never satisfied by `--color-ink-muted`.
