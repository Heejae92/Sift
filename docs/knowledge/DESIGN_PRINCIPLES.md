# Design Principles

v1.4 · 2026-09-24 · companion to `UI_DESIGN.md` and `DECISIONS.md`

## 0. Purpose

These are the rules a reviewer can hold a screen or a pull request against. Each one is numbered so
it can be cited in a review comment and ticked in `PRINCIPLES_CHECKLIST.md`. A principle states
what to do and what it rules out; where it comes from a recorded decision, the ADR is named.

If a principle and a token disagree, the token wins — the Swift files are canonical (ADR-001). If a
principle blocks something the product needs, change the principle in a commit of its own and say
why, rather than working around it.

## 1. Product principles

**P-01 · The screenshot is the hero.** The app is the mat around the picture. Chrome is white,
navy and quiet; the card is the largest thing on screen; the screenshot is fitted, never cropped,
because the cropped part may be the part being judged. Anything that makes the card smaller — a tab
bar, a banner, a second toolbar — has to justify itself against the card (ADR-011).

**P-02 · Three verbs, three colors, never color alone.** There are exactly three verdicts: trash,
archive, fave. Each carries four channels — a direction, a glyph, a word and a hue — and the hue is
the last of the four, not the first. Nothing in the app is distinguishable by color only. Do not add
a fourth verdict, and do not encode anything else in the verdict colors (ADR-004).

**P-03 · One queue, one step back.** Screenshots come in one queue, newest unreviewed first, with a
visible position. Undo is exactly one step, on exactly one control. Deeper mistakes are recovered
through Trash and Library, not through a longer history. A restored item re-enters the queue in date
order, not at the front (ADR-008).

**P-04 · Destruction is confirmed by the system.** Anything reversible commits with no
confirmation, because Trash and rewind are the safety net. Anything irreversible goes through the
iOS dialog, always. The one in-app sheet in the system exists for the "delete all" case, and its job
is to state the count and pre-announce the system dialog — not to replace it (ADR-009).

## 2. Visual principles

**P-05 · Light only, white canvas.** One color scheme. Every token is one fixed OKLCH value; there
are no adaptive pairs and no dark contrast table. `canvas` and `surface` are pure white so a
screenshot is never tinted by what is behind it (ADR-006).

**P-06 · Saturation is reserved for verdicts and blocks.** The three verdict colors appear in four
places: the stamps, the three verdict buttons, the Trash count badge, and the destructive button.
The destructive button is a `trash.main` fill with a **navy `ink`** label, measured 4.61:1, not
white on tomato: `DSTextRole.label` is 16 pt bold, below WCAG's 19 pt bold floor, so white would sit
at 3.51:1 against a 4.5 bar (ADR-004). The five expressive colors appear only as full-bleed blocks
on onboarding and empty states, and the borrowing runs one way only. The expressive palette never
carries verdict meaning; the reverse is not symmetrical, because two of the seven blocks
deliberately borrow a verdict color instead of an expressive one, onboarding taking `trash.main` and
the limited-access interstitial `fave.soft`, and there is no third (ADR-016). The `DSBlock` header
comment in `DSIllustration.swift` now states that asymmetry in those terms; it no longer claims that
verdict colors are never used as blocks. Everywhere else the app is white and navy. There is no
saturated accent, no green success and no red error: success is a haptic plus a sentence, an error
is navy text with the warning glyph (ADR-005).

**P-07 · Navy ink, not black.** Text, icons, the primary button fill and both shadow layers are all
the same navy. Pure black appears in exactly one place, the asset viewer's background, where the
subject is a photograph.

**P-08 · Typeset, don't draw.** Every figure in the app — faces, empty states, onboarding — is set
from glyphs. A face is one line, not two: a pair of round parentheses is the head, and a single glyph
borrowed from a world script is the eyes and the mouth at once. `DSFace` has seven cases, one per
`DSBlock`, and no glyph is used twice. Only the parentheses come from the display face, Forager Bold
Overlap; each centre glyph is drawn by whichever system font carries its script, and the weight
contrast between a heavy Latin bracket and a lighter non-Latin glyph is the intended look. It is also
why a face never carries information: faces are `accessibilityHidden` and the headline under the
block says what happened. There are no illustration assets, so there is no export step, no asset
catalog to keep in sync, and nothing to redraw when the palette changes (ADR-016).

**P-09 · No borders; shadows only float.** Surfaces separate by tint and whitespace. The focus ring
is the only stroke in the system. Shadows are two soft layers at 10 % and 5 % and belong only to
things that float: the front card, a committed stamp, the verdict buttons, the toast, sheets. A
thumbnail does not float; a segmented control does not float (ADR-006).

**P-10 · Radius follows padding, and nested radius is outer minus gap.** A control padded by 12
takes radius 12; a card padded by 24 takes radius 24; a thumbnail inset by 8 inside a radius-12
container computes 12 − 8 = 4, and because the scale has no token below `DSRadius.xs` (6) the result
**clamps up** to `xs`. Clamping up is legal only while the inner radius stays smaller than the outer
one — 6 < 12 holds here. When the arithmetic and that constraint cannot both be satisfied, the gap
is wrong, not the token: change the inset. Concentric corners look wrong when the inner radius is
not smaller than the outer one. Every rounded shape is `.continuous` (ADR-018).

## 3. Code conventions

**P-11 · Everything lives in the `DS` namespace.** The nine token files declare twenty-two types:
`DSColor` and `VerdictColorSet`; `DSFont` and `DSTextRole`; `DSSpace`, `DSRadius`, `DSGrid`,
`DSSize`, `DSSwipe`; `DSShadow` and `DSLayer`; `DSMotion` and `DSPressStyle`; `DSHaptic` and the
private `DSHapticModifier`; `DSIconRef`, `DSIcon`, `DSIconCredit`, `DSIconCredits`; `DSFace` and
`DSBlock`; and `Brand`. Two of the twenty-two carry no `DS` prefix, and both are deliberate: `Brand`,
the one place the product name is typed (ADR-002), and `VerdictColorSet`, the three-color value
`DSColor` hands back per verdict. In Swift the product name appears in
`Brand.swift` and nowhere else, and the lint fails if it leaks into another token file — that is the
whole of what the lint can promise, because it scans `Sift/DesignSystem/*.swift` only. A rename is
one Swift constant plus the prose that names the product: the guide, the document titles, and the
copy strings quoted in `DECISIONS.md` (ADR-002 lists the count per file). What must stay brand-free
is the token layer: no `DS` type, CSS variable or asset name ever carries the name.

**P-12 · No literals outside `DesignSystem/`.** No hex string, no point value, no duration, no
spring constant is typed in a view. If a screen needs a number that does not exist, add a token and
run all four verification commands (P-23); do not inline it "just here". A number that appears twice
in two files has already drifted once.

**P-13 · Only the four modifiers.** Type is applied with `.dsType(_:)`, shadow with
`.dsShadow(_:)`, haptics with `.dsHaptic(_:trigger:)`, focus with
`.dsFocusRing(_:cornerRadius:color:)`. No view calls `.font(...)` with a literal, no view calls
`.shadow(...)` directly, and nothing touches a feedback generator. Each modifier is the single place
where a cross-cutting detail lives — `compositingGroup()` before a shadow, the 90 ms second pulse
for FAVE — and bypassing it loses that detail silently.

The focus modifier is the one that takes a color, and the parameter is deliberate rather than a
convenience: the ring is translucent, so its ratio depends on what it sits on. `color` defaults to
`DSColor.focus`, which is measured on the neutral surfaces, and a control on a full-bleed color
block passes `DSBlock.focusRing` instead (ADR-023). Passing a color is not an escape from the
modifier. The value has to be a token with a measured row behind it, which is why the parameter
takes a token and never a literal.

**P-14 · Icons only through `DSIconRef.image`.** No `Image(systemName:)` and no `Image(_:)` in a
view. The reference decides whether the catalog asset or the development fallback is used, and it is
the thing the credits screen enumerates. A hard-coded SF Symbol will still render after the real
asset lands, which is how an icon ends up uncredited (ADR-017).

**P-15 · Every animation is `gated`.** Animations are created through
`DSMotion.gated(_:reduce:)` with `@Environment(\.accessibilityReduceMotion)`, never by passing a
raw curve to `withAnimation`. Where the Reduce Motion table in `UI_DESIGN.md` §6 prescribes a
*substitute* rather than a removal, use the second overload, `DSMotion.gated(_:reduce:reduced:)`,
and pass a named token: `DSMotion.snapBackReduced` (linear, `dur1` = 0.12 s) or `DSMotion.crossFade`
(linear, `fade` = 0.18 s). Substitution does not license a curve at the call site — if a replacement
has no token yet, add one to `DSMotion` and pass that. Reduce Motion is then honored at one choke
point instead of at every call site, and a new animation cannot forget it.

A blanket reset must exclude whatever implements a substitution. The rule binds the HTML guide as
well, where Reduce Motion arrives as a media query rather than as an environment value: the guide's
`prefers-reduced-motion` block cuts every duration to `.01ms !important`, and that `!important`
would overwrite the two substitutions the guide exists to demonstrate. So the selector carves the
deck out through `:not(:where(.deck__card, .deck__card *))`; `:where()` keeps the exclusion at zero
specificity, so the rule still carries the weight it always did, and everything outside the deck
still takes the cut (ADR-024). Verified in a browser with the query emulated: the snap-back measures
0.12 s linear (`DSMotion.snapBackReduced`, which is `dur1`), a commit holds the stamp for
`DSMotion.stampHoldReduced` and then cross-fades, and a chrome button measures 1e-05 s, the blanket
cut. `revert-layer` does not do this job: with no cascade layers declared it rolls back to the UA
value, 0 s, which is the same instant cut. A demonstration that deletes a substitution contradicts
the rule it is demonstrating.

**P-16 · `preferredColorScheme(.light)` at the root.** The root view pins the scheme. Nothing else
reads `colorScheme`, and no token has a dark variant. A user running iOS in dark mode sees a light
app; that trade-off is recorded, not accidental (ADR-006).

## 4. Patterns

**P-17 · Token, then component, then screen.** A value becomes a token, a token becomes part of a
component, a component becomes part of a screen. A screen never reaches past a component to a raw
value, and a component never hard-codes a screen's needs. When a screen wants something a component
does not offer, extend the component or add a variant to it — do not fork it.

**P-18 · State is an enum, and every case is designed.** Each component declares its states as an
enum, and each state appears in `UI_DESIGN.md` with its visual treatment. Loading, empty, error and
disabled are states, not afterthoughts: a screen is not finished while any of its cases is
undesigned. An empty state is a designed screen with a block, a face and a headline, not a blank
view with a centered sentence.

## 5. Accessibility

**P-19 · Contrast is enforced, not reviewed.** Text clears 4.5:1; large text and non-text clear 3:1,
where **large means ≥ 24 pt regular or ≥ 19 pt bold**. Bold weight on its own does not lower the
bar: a 16 pt bold label is normal text and needs 4.5:1. On a verdict `main` fill that leaves exactly
two things at the 3:1 bar — the 32 pt stamp word and the icon glyphs, which use the verdict's `on`
color; every smaller label on such a fill is `ink`, measured at 4.61 on tomato and 10.20 on yellow
(ADR-004). Cobalt is the one measured exception: white on `archive.main` reaches 6.57, which clears
the 4.5 text bar on its own, so a white label on cobalt is legal at label size (the generated row
whose use column reads `text · white label on a cobalt fill`). What gates an `on` color at small
sizes is its measurement, not its name. The script fails on any regression across all 43 pairs.
Exemptions are explicit rows in the generated table with a written reason, and there are three: the
yellow edge against `canvas`, the same edge against a white screenshot, and the raised fill against
`canvas`. An exemption that is not in the table is a bug. On the neutral surfaces the tightest
measured rows are `ink2` on `surfaceRaised` at 6.19 and `inkMuted` on `surfaceRaised` at 4.77, which
is why an ink-ramp change is checked against `surfaceRaised` rather than against `canvas`. The
`DSColor` doc comments carry those two figures now, in place of a rounded 6.0.

The focus ring is measured like everything else. `DSColor.focus` is `ink` at 60 %, 3 pt
(`DSSize.focusRing`), and it has its own two rows: 4.34 over `canvas` and 4.06 over `surfaceRaised`,
both against the 3:1 non-text bar (ADR-021). A focus indicator reports state, so it is never
exempted as decoration. Because the ring is translucent its ratio depends on what it sits on, so a
new surface token needs its own row before it may host a focusable control. That dependence is
visible in the helper's signature: `dsFocusRing(_:cornerRadius:color:)` takes the ring color, with
`DSColor.focus` as the default, precisely so a control on a saturated block can pass
`DSBlock.focusRing`. Any statement that the helper hard-codes `DSColor.focus` describes an older
signature and is wrong.

A color placed on a block follows the block's ink; it is not a free choice. `DSBlock` derives the
three colors a screen might otherwise pick for itself: `ctaFill`, `ctaLabel` and `focusRing`. The
call-to-action pill inverts the block's ink pair — `DSBlock.ctaFill` is the block's own ink and
`DSBlock.ctaLabel` is that ink's counterpart, `DSColor.onAccent` on the six blocks whose ink is
`ink` and `DSColor.accent` on `denied`, the one block whose ink is `onAccent`. `DSBlock.focusRing`
is the block's ink at full strength, not `DSColor.focus`. Both rules are measured, and both replace
a choice that failed. A white pill is invisible as a shape on its own block: 1.15 on `lime`, 1.15 on
`fave.soft`, 1.53 on `pink`, 1.79 on `mint`, 2.61 on `lavender`; a navy pill on `violet` is 2.33.
Filled with the block's ink the pill clears 4.61 at worst (tomato) and 14.01 at best (pale yellow)
on all seven blocks, and its label clears 16.16 on the two generated rows written for it, `onAccent`
on `ink` and `accent` on `onAccent`. `DSColor.focus` is ink at 60 %, tuned for the neutral surfaces;
composited over a saturated block it drops to 2.65 on tomato, 2.92 on lavender and 1.71 on violet,
all under the 3:1 non-text bar, while the ink ring at full strength is the pair the block's own copy
already passes. Neither rule needed a row of its own: the pill against its block and the ring
against its block are the same pair as `ink` on that block, which the block copy rows already
enforce at the stricter 4.5 text bar. Two rows were added for the pill label, and that is what took
the table from 41 pairs to 43.

A block carries exactly ONE filled action. A second action on a block is bare text in the block's
ink, never a second pill and never the secondary fill. The reason is the same measurement rule read
forwards: a filled control is a shape, a shape owes 3:1 against what it sits on, and a secondary on
a block would owe that row against all seven fills rather than against one surface. It does not have
them. `surfaceRaised` measures 2.16 against `lavender`, 1.05 against both `lime` and `fave.soft`,
1.26 against `pink`, 1.48 against `mint` and 2.90 against `trash.main`, and clears the bar on
exactly one block, `violet` at 5.74. With no fill there is no shape to measure at all, only the
label, and the label is the block's own ink on the block, which the block-copy rows already clear at
the stricter 4.5 text bar. The guide names the three legal forms as CSS classes: `.btn--onblock` is
the navy pill with a white label, `.btn--onblock-inverted` is the white pill with a navy label that
`violet` takes, and `.btn--onblock-text` is the bare-text second action. The seven figures above are
not in the generated table, because a secondary on a block is not a legal pair; re-derive them from
the Swift tokens with

```
python3 -c 'import sys; sys.path.insert(0, "scripts"); import ds_tokens as d; t = d.parse_colors(); f = lambda n: d.rgb_of(t[n]); print({b: round(d.contrast(f("surfaceRaised"), f(b)), 2) for b in ["trash.main", "lime", "mint", "pink", "lavender", "fave.soft", "violet"]})'
```

which printed, on 2026-09-24:

```
{'trash.main': 2.9, 'lime': 1.05, 'mint': 1.48, 'pink': 1.26, 'lavender': 2.16, 'fave.soft': 1.05, 'violet': 5.74}
```

**P-20 · Ten roles scale; `stamp` is capped instead.** Ten of the eleven `DSTextRole` cases bind to
a Dynamic Type text style through `relativeTo:`, and grow with the user's setting. `stamp` is bound
to no text style at all, and that is the designed exception: the call site owns the scaling —
`@ScaledMetric(relativeTo: .largeTitle) private var stampSize = DSTextRole.stampBaseSize` (32) — and
passes the result to `DSTextRole.stampFont(size:)`, which clamps it to `stampMaxSize` (44) and
returns `DSFont.displayFixed`, a **fixed-size** font. Binding it as well would scale the value twice
and the 44 pt cap would not hold. `stamp.font` via `dsType` is the unscaled 32 pt form, for previews
and the style guide only. So do not write that every role binds or that everything scales: ten bind,
and the eleventh is capped on purpose. Layouts wrap rather than truncate, and a destructive label
never drops its count to fit. `caption` is never used as a rung above `body`, because the two
converge at accessibility sizes.

**P-21 · 44 pt is a floor.** Every interactive element is at least `DSSize.tapMin` in both
dimensions. Where the glyph is smaller, the hit area is padded — never the glyph.

**P-22 · VoiceOver gets the same facts, in the same order.** The front card is one element carrying
date, size and position. Verdicts are custom actions in a fixed order: Trash, Archive, Favorite,
Rewind last. After a commit, an announcement gives the verdict and the new position in one sentence,
which is exactly what a sighted user reads off the stamp and the counter. Decoration — stamps, faces,
cards behind the front card — is `accessibilityHidden`.

## 6. Verification

**P-23 · Four commands, and the output, before any claim.** Nothing is "done" on inspection. Run
all four and paste what they printed:

```
python3 scripts/ds_tokens.py contrast
python3 scripts/ds_tokens.py emit-css > scripts/out/tokens.css
python3 scripts/ds_tokens.py lint
scripts/typecheck-ds.sh
```

`contrast` must print `43 pairs · 0 failure(s)` and no gamut warning. `emit-css` output must be
pasted into the guide's `:root` block, which is what `lint` compares against. `lint` must print
`lint: OK` on its last line. `typecheck-ds.sh` must print `typecheck: OK`. A token change that skips
`emit-css` leaves the guide stale, and `lint` is the only thing that catches it.

A passing `lint` is not a silent one. It also prints three `lint: EXCEPTION` lines for the variables
the guide declares but cannot consume (`--grid-breakpoint`, `--motion-dur3`,
`--motion-toast-visible`) and, until the Noun Project credits land, one `lint: WARNING` line for the
empty `DSIconCredits.entries` (ADR-022, ADR-017). Those four lines are expected output; read the last
line for the verdict.

What `lint` actually checks is worth stating exactly, because "unused variable" is easy to misread.
Usage is counted by **exact name, outside comments**: the lint strips `<!-- ... -->` from the HTML
first, then matches each variable with a trailing-character guard, and requires two occurrences, the
declaration in the generated `:root` block plus at least one real use. So `--color-ink` is not
satisfied by `--color-ink-muted`, and a variable mentioned only in a comment counts as unused. The
allowlisted variables in `DECLARATION_ONLY` print as `EXCEPTION` lines rather than being silently
tolerated, and each entry carries its reason as the dictionary value. The empty icon-credits array
is a `WARNING`, not a failure: it does not change the exit code, and `lint` still ends in `lint: OK`.
The module docstring at the top of `scripts/ds_tokens.py` describes the same three behaviours.

## Changelog

| Version | Date | Change |
|---|---|---|
| v1.0 | 2026-09-23 | First set. P-01 to P-23, derived from ADR-001 to ADR-020. Supersedes the dark-first, SF Rounded, SF Symbols direction recorded as S-1 to S-4. |
| v1.1 | 2026-09-24 | Code-review corrections, no new principle numbers. P-19: large text is ≥ 24 pt regular or ≥ 19 pt bold, so bold alone never lowers the bar; three exemption rows named; focus ring paragraph added (ADR-021). P-10: nested radius clamps up to `DSRadius.xs` (6), it does not go below 4. P-15: substitutions go through `gated(_:reduce:reduced:)` with named tokens. P-20: `stamp` scales at the call site and returns a fixed-size font. P-11: the rename scope restated honestly (ADR-002). P-12 and P-23: four verification commands, and `lint`'s EXCEPTION and WARNING lines are expected output (ADR-022). |
| v1.2 | 2026-09-24 | Token corrections, no new principle numbers. P-06: the destructive button is named as the fourth place a verdict color appears, and it is `trash.main` with a navy `ink` label at 4.61:1, not white on tomato; the two blocks that borrow a verdict color are named. P-08: a face is round parentheses from Forager Bold Overlap plus one world-script glyph drawn by the system font that carries it, seven faces for seven blocks, no glyph twice (ADR-016). P-11: all twenty-two declared types listed, with `Brand` and `VerdictColorSet` as the two deliberate non-`DS` names. P-20: retitled, because `stamp` binds to no Dynamic Type style; ten roles bind, `stamp` is scaled at the call site and returned fixed-size so the 44 pt cap cannot be scaled twice. |
| v1.3 | 2026-09-24 | Code corrections, no new principle numbers. P-19: cobalt named as the one measured exception, because white on `archive.main` reaches 6.57 and clears the 4.5 text bar on its own, so what gates an `on` color at label size is its measurement and not its name; a paragraph added binding every color on a block to `DSBlock`, where `ctaFill` is the block's ink, `ctaLabel` that ink's counterpart and `focusRing` the ink at full strength, with the measured reasons and the note that only the pill label needed new rows; the table is 43 pairs. P-15: a blanket Reduce Motion reset must exclude whatever implements a substitution, and `revert-layer` does not do that job because with no cascade layers it rolls back to 0 s. P-23: `contrast` now prints 43 pairs. |
| v1.4 | 2026-09-24 | Code corrections, no new principle numbers. P-13: the focus modifier is `.dsFocusRing(_:cornerRadius:color:)`; the color is a parameter defaulting to `DSColor.focus`, and a control on a block passes `DSBlock.focusRing` (ADR-023). P-19: a block carries exactly one filled action, so a second action is bare text in the block's ink, with the seven `surfaceRaised`-against-block figures and the command that re-derives them; the `ink2` 6.19 and `inkMuted` 4.77 rows on `surfaceRaised` named as the tightest of the ink ramp; the focus paragraph records that the helper takes a color. P-06: the expressive-to-verdict rule stated as one-way, matching the `DSBlock` header comment. P-23: what `lint` counts, spelled out as exact name outside comments, `DECLARATION_ONLY` entries printing as EXCEPTION lines, and the empty icon-credits array being a WARNING and not a failure. Cross-file row and line citations replaced by the pair or the selector they name. |
