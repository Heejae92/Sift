# Decisions (ADR log)

> Companion to `UI_DESIGN.md` and `DESIGN_PRINCIPLES.md`. One entry per design decision that a
> later reader could reasonably question. Format: context → options → decision → consequences,
> with an **Applies to** line on entries from ADR-021 onward naming the tokens and principles the
> decision governs.
> When a decision is replaced, the old entry stays and gets a **Superseded by** line; nothing is
> deleted. When a decision that is still active turns out to rest on a wrong premise, it keeps its
> number and gains a dated **Correction** paragraph that quotes what it used to claim; the original
> wording is never silently rewritten. A correction never renames an entry, and never rewrites its
> body: a heading and its number are link targets, so ADR-003 still carries the typeface it
> originally chose, its Context, Options, Decision and Consequences still describe that choice, and
> only its **Correction** paragraphs name the face in force. Dates are the day the owner confirmed
> the decision — or, for the entries that carry an **Applies to** line, the day the code review or
> the measurement that forced them landed.
>
> **Correction, 2026-09-24 (this preamble).** The sentence above used to end "so ADR-003 still
> carries the typeface it originally chose while its body and its correction name the one in force".
> ADR-003's body does not name the face in force anywhere: its Context, Options, Decision and
> Consequences read Acme Gothic from first line to last, and only the correction paragraphs name
> Forager Bold Overlap. There were two ways to close that gap and only one of them is honest. Writing
> the promised wording into ADR-003's body would silently rewrite an original decision, which is the
> one thing the two sentences before this forbid, and it would destroy the record of what was
> actually decided on 2026-09-23. So the preamble is what changed. The preamble is not a numbered
> entry and nothing links to it; it states the log's rules, and a rule that describes itself wrongly
> is a defect in the rule, not a superseded decision.
>
> **Correction, 2026-09-24 (the ADR range was typed, not derived).** The sentence about dates used to
> read "or, for ADR-021 through ADR-024, the day the code review or the measurement that forced them
> landed". That range was true the day it was written and would have gone wrong the day ADR-025
> landed. It now names the predicate, and the range itself is derived from the headings in this file.
> Run from the repository root; these are basic-regex patterns, so plain `grep`, no `-E`.
> `grep -c '^## ADR-' docs/knowledge/DECISIONS.md` returns **24**.
> `grep -o '^## ADR-[0-9]*' docs/knowledge/DECISIONS.md` lists them in order: ADR-001 to ADR-024, no
> gaps, ADR-024 highest. `grep -c '^\*\*Applies to\*\*' docs/knowledge/DECISIONS.md` returns **4**,
> and they are ADR-021, ADR-022, ADR-023 and ADR-024. `grep -c '^### S-'` on the same file returns
> **4** superseded entries under the last heading. All four counts taken 2026-09-24. The **Applies
> to** sentence above keeps "from ADR-021 onward", which states where the convention started rather
> than a range a later reader has to re-count.

## Index

| ADR | Title | Date | Status |
|---|---|---|---|
| 001 | Swift tokens are canonical; CSS, contrast table and lint are generated | 2026-09-23 | Active |
| 002 | Brand-neutral `DS` prefix; the product name lives in one file | 2026-09-23 | Active · corrected 2026-09-24 |
| 003 | Type: Acme Gothic for display, Pretendard for text; Acme Gothic is web-only for now | 2026-09-23 | Active · corrected 2026-09-24 |
| 004 | Verdict colors: tomato · cobalt · golden yellow; yellow's edge is exempt | 2026-09-23 | Active · corrected 2026-09-24 |
| 005 | Monochrome navy accent; no success/error hues | 2026-09-23 | Active · corrected 2026-09-24 |
| 006 | Light only, white canvas; elevation and layering inherited from the reference system | 2026-09-23 | Active |
| 007 | Haptic vocabulary: impact weight encodes direction | 2026-09-22 | Active |
| 008 | Undo is a single-step rewind | 2026-09-22 | Active |
| 009 | Permanent deletion always goes through the iOS dialog; "delete all" gets an in-app sheet first | 2026-09-22 | Active · corrected 2026-09-24 |
| 010 | Limited photo access is a first-class state | 2026-09-22 | Active |
| 011 | Navigation by header icon buttons, no tab bar | 2026-09-22 | Active |
| 012 | No sound in v1 | 2026-09-22 | Active |
| 013 | Stamps read TRASH / ARCHIVE / FAVE and are pills | 2026-09-23 | Active |
| 014 | The archive album is named "<Brand> Archive" | 2026-09-22 | Active |
| 015 | Trash has no multi-select | 2026-09-22 | Active |
| 016 | Typographic faces on expressive color blocks | 2026-09-23 | Active · corrected 2026-09-24 |
| 017 | Icons from the Noun Project, bold solid, CC BY credits | 2026-09-23 | Active |
| 018 | Spacing, radius and grid inherited verbatim from the reference system | 2026-09-23 | Active |
| 019 | Swipe physics: four 90° sectors, 120 pt / 800 pt·s⁻¹ commit | 2026-09-22 | Active |
| 020 | Documentation in English; the HTML guide mirrors the reference format | 2026-09-23 | Active · corrected 2026-09-24 |
| 021 | The focus ring is `ink` at 60 %, not 45 % | 2026-09-24 | Active · corrected 2026-09-24 |
| 022 | The token script fails loudly; CSS-variable usage is counted exactly | 2026-09-24 | Active · corrected 2026-09-24 |
| 023 | The CTA pill and the focus ring on a color block are the block's own ink | 2026-09-24 | Active · corrected 2026-09-24 |
| 024 | The guide's reduce-motion cut excludes the deck, so the substitutions run | 2026-09-24 | Active |
| 025 | Information architecture: a derived queue, four screens, four assumptions | 2026-09-27 | Active |
| S-1 | Dark-first adaptive tokens | 2026-09-22 | Superseded by 006 |
| S-2 | SF Pro Rounded system font | 2026-09-22 | Superseded by 003 |
| S-3 | SF Symbols as the icon set | 2026-09-22 | Superseded by 017 |
| S-4 | 4-pt spacing scale and rounded-rectangle stamps | 2026-09-22 | Superseded by 018 / 013 |

---

## ADR-001 · Swift tokens are canonical; CSS, contrast table and lint are generated

**Context.** The previous app kept the Markdown document as the source of truth and mirrored it
by hand into Swift; every tuning pass had to be copied twice and the two drifted.

**Options.** (a) Markdown canonical, Swift mirrored by hand. (b) A JSON token file with a build
tool (Style Dictionary). (c) Swift canonical, one script derives the rest.

**Decision.** (c). `Sift/DesignSystem/*.swift` is the only place a value is typed.
`scripts/ds_tokens.py` parses those files and produces the WCAG contrast table (pasted into
`UI_DESIGN.md`), the `:root` custom-property block for `design-system.html`, and a lint that
fails when a token is missing from the HTML or the doc, or when the pasted CSS is stale.

**Consequences.** Token files must keep the literal shapes the parser expects
(`oklch(L, C, H[, a])`, `<token>.opacity(a)`, `static let name: CGFloat = v`), and since ADR-022 a
declaration the parser cannot read aborts the run instead of quietly dropping out of the table.
Adding a token means running all four verification commands — `contrast`, `emit-css`, `lint` and
`typecheck-ds.sh`; `PRINCIPLES_CHECKLIST.md` lists the four.

## ADR-002 · Brand-neutral `DS` prefix; the product name lives in one file

**Context.** The product name ("Sift") is provisional.

**Decision.** Every type under `Sift/DesignSystem/` carries the `DS` prefix and no brand. Sixteen
enums: `DSColor`, `DSFont`, `DSTextRole`, `DSSpace`, `DSRadius`, `DSGrid`, `DSSize`, `DSSwipe`,
`DSShadow`, `DSLayer`, `DSMotion`, `DSHaptic`, `DSIcon`, `DSIconCredits`, `DSFace`, `DSBlock`. Three
structs: `DSIconRef`, `DSIconCredit`, `DSPressStyle`. Modifiers are `.dsType(_:)`, `.dsShadow(_:)`,
`.dsHaptic(_:trigger:)` and `.dsFocusRing(_:cornerRadius:)`, plus the button style `.dsPress`. CSS
variables carry no brand prefix.

Three types sit outside that pattern, each for a stated reason. `VerdictColorSet` is the three-color
value behind each verdict: brand-neutral, but a struct the tokens hold rather than a namespace of
tokens, so it takes no prefix. `DSHapticModifier` is `private` and is never named at a call site.
`Brand` is the one place the product name is typed (`Brand.name`, with `Brand.archiveAlbumTitle`
interpolating it); `scripts/ds_tokens.py lint` fails if the word appears in any other file under
`Sift/DesignSystem/`.

**Consequences.** No `DS` type, CSS variable or asset name carries the brand, so the whole token
layer survives a rename untouched. That is what this ADR actually buys.

**Correction, 2026-09-24.** This ADR used to promise that "renaming the app is a one-line change
plus two document headers". It is not, and the lint cannot back the promise: `ds_tokens.py lint`
scans `Sift/DesignSystem/*.swift` only, so every occurrence outside that directory is invisible to
it. Counted on 2026-09-24, the real scope of a rename is:

| Where | Occurrences | What they are |
|---|---|---|
| `Sift/DesignSystem/Brand.swift` | 1 | `Brand.name`, the one Swift literal |
| `design-system.html` | 8 | page title, sidebar logo, hero eyebrow, one type specimen, one screen mock-up headline, one button label, two block copy strings |
| `docs/knowledge/UI_DESIGN.md` | 1 | the title line |
| `docs/knowledge/DECISIONS.md` | 3 | the ADR-002 context line and the two copy strings quoted in ADR-010 |

So the honest statement is: one Swift constant, plus the guide, plus the document headers and the
product copy quoted in prose. Directory and repository names are not driven by `Brand.name` and
would be renamed by hand. Nothing here weakens the token-level benefit above; the promise was
simply larger than the lint's reach.

**Correction, 2026-09-24 (the type list).** The list above used to name fourteen types and stop:
`DSColor`, `DSTextRole`, `DSSpace`, `DSRadius`, `DSGrid`, `DSSize`, `DSSwipe`, `DSShadow`, `DSLayer`,
`DSMotion`, `DSHaptic`, `DSIcon`, `DSFace`, `DSBlock`. Read off the Swift files, five were missing:
`DSFont` (the PostScript names and the per-cut fallback probe, `DSTypography.swift`), `DSIconRef`,
`DSIconCredit` and `DSIconCredits` (`DSIcon.swift`), and `DSPressStyle` (`DSMotion.swift`). The
modifier list was missing the button style `.dsPress`, and neither `VerdictColorSet` nor the private
`DSHapticModifier` was accounted for at all. An inventory that is not complete cannot be checked
against the source, and being checkable is the whole point of this entry.

**Correction, 2026-09-24 (the rename-scope count).** The table above gives `design-system.html` as
**8** occurrences of the product name and enumerates seven kinds. Counted in the current file, it is
**10**, on ten separate lines, and two kinds were missing. (This table listed those ten line numbers
until 2026-09-24, when they were struck out under the rule against citing line numbers in another
file. The locators below are what replaced them; nothing else in the table changed.)

| Where on the page | What it is |
|---|---|
| `<head>` | the `<title>` |
| sidebar | `.nav__logo`, the logo |
| hero | `.eyebrow` |
| 03 Typography | type specimen, the `headline` row |
| 03 Typography | type specimen, the `body` row |
| 07 Interaction & Motion | `.btn--onblock` label in the on-block button demo |
| 07 Interaction & Motion | `.sheet-mock__sheet` body, the purge-all sheet |
| 09 Screens | onboarding mock-up headline |
| 09 Screens | `.b-violet` block copy, `denied` |
| 09 Screens | `.b-limited` block copy, `limited` |

So it is **two** type specimens, not one, and **two** strings inside the screen mock-ups, not one.
Both misses are the same kind: a copy string that appears twice on the page, once as a specimen of
the type role and once inside the mock-up that uses it. The purge-all sheet body is quoted in 07
Interaction and again as the `body` specimen in 03 Typography; the onboarding headline is quoted in
09 Screens and again as the `headline` specimen.

The corrected total across the four files is 1 + 10 + 1 + 3 = **15** occurrences, not 13. The other
three rows were right and are unchanged, and so is the conclusion this entry draws: the token layer
carries no brand, and what a rename touches is one Swift constant plus product copy quoted in prose.
Directory and repository names are still renamed by hand and are still not counted here.

**Correction, 2026-09-24 (line numbers out, commands in; and the per-file counts recounted).** The
correction above located each of the ten occurrences in `design-system.html` by line number. Nine of
those ten numbers had gone wrong: the page was edited after they were written, and a line number in
another file is a claim that decays the moment that file changes. The count survived and so did every
kind; only the coordinates rotted. They are struck from the table above and replaced by a section and
a selector each, which is what a reader needs in order to find them and what a page edit cannot
invalidate; all ten are still reached in one step by `grep -n 'Sift' design-system.html`, run from the
repository root. This log stops citing line numbers in any other file, here and in every other entry
that did so. What replaces a line number is a stable locator, plus, where a number genuinely helps,
the command that returns it.

The per-file table higher up needs recounting as well, and the recount is why it is now a rule and a
command rather than a column of totals. Its Occurrences column counts the product name **as product
copy**. It does not count the string. The same string is also the source directory
`Sift/DesignSystem/`, a `ROOT` path join, and the search pattern inside commands like the ones below,
and a rename drives none of those. So a plain grep returns more than the table says in every file
except the guide, and what it returns keeps moving: three of the five files below were edited by other
hands in the same pass that wrote this paragraph, and this document's own total moves every time the
log gains a path reference, including by this paragraph.

What a rename touches, therefore, stated as the rule with the command that lists every candidate for a
human to classify. All five commands run from the repository root; the counts are the product-copy
occurrences, taken 2026-09-24.

| File | Product copy | Command |
|---|---|---|
| `Sift/DesignSystem/Brand.swift` | 1, the `Brand.name` literal | `grep -n 'static let name' Sift/DesignSystem/Brand.swift` |
| `design-system.html` | 10, the ten kinds listed above | `grep -n 'Sift' design-system.html` |
| `docs/knowledge/UI_DESIGN.md` | 1, the title line | `grep -n 'Sift' docs/knowledge/UI_DESIGN.md` |
| `docs/knowledge/DECISIONS.md` | 3, the ADR-002 context line and the two copy strings quoted in ADR-010 | `grep -n 'Sift' docs/knowledge/DECISIONS.md` |
| `README.md` | 0 | `grep -n 'Sift' README.md` |

1 + 10 + 1 + 3 + 0 = **15**, which is the total the correction above reached, with `README.md` added as
a fifth file that contributes nothing. Every occurrence the commands list and this column does not
count is a path, a path join or a search pattern, and a reader can tell which by looking at the line.
That is the durable form: the classification rule plus the listing command, with the totals dated.

`README.md` is a new row and it reads zero, which corrects something outside this document. The doc
comment on `Brand` still says a rename touches "the header lines of `docs/knowledge/UI_DESIGN.md` and
`README.md`". `README.md` has no header line carrying the product name: its title is `# Design
system` and both of its occurrences are the source path. `UI_DESIGN.md` §0 has already dropped
`README.md` from its own list of the prose that names the product, so the Swift doc comment is the
last place that claim survives. It is a file this document does not own and it needs the same fix.

One inventory item in this entry has drifted in the other direction, in Swift rather than in prose.
The modifier list above gives `.dsFocusRing(_:cornerRadius:)`. The declared name is now
`.dsFocusRing(_:cornerRadius:color:)`, because the ring color became a parameter (ADR-021's
correction, ADR-023). The two-label form is still a legal call site, since `color` defaults to
`DSColor.focus`, so nothing written against the old spelling breaks. But the declaration the list
points at has three labels, and an inventory that cannot be checked against the source is exactly
what this entry's own corrections keep saying it must not be.

## ADR-003 · Type: Acme Gothic for display, Pretendard for text; Acme Gothic is web-only for now

**Context.** The owner chose Acme Gothic (Mark Simonson Studio) for titles and Pretendard for
body text. Acme Gothic ships through Adobe Fonts, whose license covers web and desktop use but
not embedding in a mobile app; an app license is a separate purchase from the foundry.
Pretendard is SIL OFL and can be bundled.

**Options for the app.** (a) Buy the app license and bundle Acme Gothic. (b) Declare Acme Gothic
in the tokens, fall back to Pretendard Bold at runtime until the license exists. (c) Replace it
everywhere with a free look-alike.

**Decision.** Acme Gothic, Regular width: **Bold** for `headline` / `title`, **Black** for
`display` and `stamp`. Pretendard Regular / Medium / SemiBold / Bold for every text role.
Option (b) for the app: `DSFont` probes **each display cut separately** — `displayAvailability`
checks `AcmeGothic-Bold` and `AcmeGothic-Black` once each, and `resolvedDisplay(_:)` returns
`Pretendard-Bold` for whichever cut is missing. Per-cut probing matters because the kit's current
state (Bold but no Black) is exactly the state a partial app license would produce: one probe for
both cuts would either bundle Black that is not there or throw away Bold that is. The HTML guide
loads Acme Gothic from Typekit kit `blt4ith`
(`<link rel="stylesheet" href="https://use.typekit.net/blt4ith.css">`, family `acme-gothic`, weights
400 and 700 as of 2026-09-24 — the Black cut still has to be added to the kit); without the kit it
renders the same fallback stack so nothing silently changes shape.

**Consequences.** Titles look slightly different in the app until the license lands; the
hierarchy (size + weight) is identical either way. Verify the PostScript names
(`AcmeGothic-Bold`, `AcmeGothic-Black`) with `UIFont.familyNames` when the files arrive. On the web
the same gap shows: `display` and `stamp` render at 700 rather than 900 until the Black cut is added
to kit `blt4ith`.

**Correction, 2026-09-24.** The display face is not Acme Gothic. It is **Forager Bold Overlap**:
`DSFont.displayBold` and `DSFont.displayBlack` both resolve to `"Forager-BoldOverlap"`. The heading
above keeps the face this entry originally chose, because the heading and its number are link targets;
everything from here down is what ships.

What changed:

- **The face.** Forager Bold Overlap replaces Acme Gothic on `display`, `headline`, `title` and
  `stamp`.
- **There is no Black cut, and there will not be one.** Forager Overlap has no weight heavier than
  Bold, so the two display slots name the same face. The slot names stay separate because the roles
  do: a wordmark and a screen title are not the same thing, and a future family may split them again.
  Every display role therefore sits at **700**. The 900 this entry promised for `display` and `stamp`
  does not exist, so the sentence about the Black cut still having to be added to the kit is void, not
  pending. `displayAvailability` keeps probing the two slots separately: it now costs one duplicate
  lookup and preserves the per-cut structure for the day a family does split.
- **The PostScript name to verify is `Forager-BoldOverlap`**, once, instead of `AcmeGothic-Bold` and
  `AcmeGothic-Black`.
- **The kit.** Typekit kit `blt4ith` serves family `forager-overlap` at 400 and 700.
- **The stylesheet link carries a cache-buster.** Typekit serves the kit with `max-age=600`, so a
  change to the kit stays invisible for ten minutes unless the URL changes. The guide's link is
  `https://use.typekit.net/blt4ith.css?v=2`, and the number is bumped on every kit edit. Without it a
  kit change looks like it did not land.

What did **not** change: Forager is also Mark Simonson Studio, also Adobe Fonts, also web and desktop
only. The license terms are identical, so option (b) stands word for word: the app declares the face
and `resolvedDisplay(_:)` returns `Pretendard-Bold` until an app license exists, and without the kit
the guide renders the same fallback stack. Pretendard Regular / Medium / SemiBold / Bold still carry
every text role.

**Display tracking is positive, not negative.** `DSTextRole.tracking` returns `34 * 0.03`, `28 * 0.03`
and `24 * 0.03` points for `display`, `headline` and `title`: **+0.03 em, 30/1000**. Forager Overlap's
strokes intentionally run into each other, so the display roles are tracked OUT to keep the letters
legible rather than optically tightened to close them up. The guide sets the same +3 % on its display
roles and `letter-spacing: 0.03em` on the face brackets. Pretendard roles keep their own tracking,
untouched by this: `subhead` and `body` at -0.01 em, `caption` at +0.01 em, and `stamp` at a flat
+2 pt, which is 0.0625 em at its 32 pt base. Any table or sentence giving display tracking as -1 % or
-0.01 em is wrong.

This is folded into ADR-003 rather than given a number of its own because it is not an independent
decision. The sign of the display tracking follows from which face is set: a separate entry would have
to restate this one as its entire context, and a new heading is a new link target that no other
document knows about. One place now answers "what is the display face, and how is it set".

**Eleven roles, ten Dynamic Type bindings.** `DSTextRole` has eleven cases and ten of them bind to a
text style through `relativeTo:`. `stamp` is the documented exception: `stampFont(size:)` clamps the
already-scaled value to `stampMaxSize` = 44 and returns `DSFont.displayFixed`, a `fixedSize` font, so
the 44 pt cap cannot be scaled twice. The call site owns `@ScaledMetric(relativeTo: .largeTitle)`
(ADR-013). A sentence saying every role binds, or that everything scales, is wrong as written.

**Correction, 2026-09-24 (`displayAvailability` was a runtime trap, not a lookup).** The bullet above
says `displayAvailability` "now costs one duplicate lookup and preserves the per-cut structure for
the day a family does split". It cost nothing, because it never ran. `displayAvailability` was a
dictionary literal keyed by the two display PostScript names, and once `DSFont.displayBold` and
`DSFont.displayBlack` both resolved to `"Forager-BoldOverlap"` that literal had two identical keys. A
Swift dictionary literal with duplicate keys does not merge them and does not quietly pay for an
extra probe: it **traps at construction**. The property is lazy, so the trap would have fired on
first use, which is the first display role rendered, which is the wordmark on the onboarding block.
The shipped app would have crashed on its first screen. A wrong premise here was not a cosmetic cost,
it was a crash the entry described as an optimisation.

It is now `DSFont.availableDisplayNames`, a `Set<String>` built in a closure that probes each name on
its own:

```swift
static let availableDisplayNames: Set<String> = {
    var found: Set<String> = []
    for name in [displayBold, displayBlack] where UIFont(name: name, size: 12) != nil {
        found.insert(name)
    }
    return found
}()
```

`resolvedDisplay(_:)` asks that Set for membership and returns `DSFont.textBold` otherwise. Two equal
names collapse into one member instead of trapping, and the per-cut structure the bullet wanted is
genuinely preserved: split the family later into two distinct names with only one of them shipped,
and the loop probes them separately and still falls back per cut rather than dropping to the system
font. Same guarantee, through a structure that tolerates the duplicate instead of dying on it. Any
sentence describing `displayAvailability`, or calling the duplicate a cost of one lookup, describes
code that is gone.

## ADR-004 · Verdict colors: tomato · cobalt · golden yellow; yellow's edge is exempt

**Context.** The owner's references are flat poster palettes (tomato, mint, golden yellow,
violet, lime, pink, cobalt, navy). Three verdicts need three colors that stay distinct under
the two common forms of color-vision deficiency and read on top of arbitrary screenshots.

**Options.** (a) tomato · cobalt · golden yellow. (b) tomato · mint · yellow — right = green =
"good" is intuitive but red/green is the most common CVD collision. (c) tomato · violet · yellow.

**Decision.** (a). `trash.main` tomato `oklch(0.65 0.19 38)` with white on it; `archive.main`
cobalt `oklch(0.50 0.24 272)` with white; `fave.main` golden yellow `oklch(0.85 0.16 92)` with
**navy** on it. Rules that follow from the measurements:

- WCAG large text is ≥ 24 pt regular or ≥ 19 pt bold. On a `main` fill only the **stamp word**
  (Forager Bold Overlap 32) and the **icon glyphs** qualify, so those are the only things that use the
  verdict's `on` color at the 3:1 bar: white on tomato 3.51, white on cobalt 6.57, navy on yellow
  10.20 (PAIRS rows 20, 22, 24).
- Every smaller label on a verdict fill uses `ink` (navy), which measures 4.61 on tomato and 10.20
  on yellow (rows 32, 34). On cobalt white itself already clears the text bar at 6.57 (row 33), so
  it stays white.
- Yellow cannot reach 3:1 against white (1.6:1) without turning ochre. Its **edge never carries
  meaning**: the navy glyph and the word FAVE do, and every verdict is also a direction and a
  word. The contrast table prints these two rows (30 and 31) as informational; the third and last
  informational row is the raised-fill tint against `canvas` (41).
- `soft` tints (`trash.soft`, `archive.soft`, `fave.soft`) carry `ink` text, never `main` text.
- Direction, glyph and word are the primary channels; hue is the third. Red and yellow both fall
  on the yellow side of a deuteranope's axis, cobalt stays apart from both — accepted.

**Consequences.** Verdict buttons are solid `main` circles with the `on` glyph (no tinted
buttons). The destructive button is navy `ink` on `trash.main` at 4.61; its label is still
`DSTextRole.label` (Pretendard Bold 16), but the weight is a typographic choice and buys no relief
from the 4.5:1 bar.

**Correction, 2026-09-24.** This ADR used to read "only bold (≥ 700) or stamp-size text sits on
`main`, so the bar there is 3:1", and concluded that a Pretendard Bold destructive label was covered
at 3:1. That premise was wrong. WCAG large text is ≥ 24 pt regular or ≥ 19 pt **bold**: bold does
not exempt a label, it only lowers the size threshold from 24 pt to 19 pt. The destructive button
label is 16 pt bold, under that threshold, so it is normal text and needs 4.5:1 — and white on
tomato measures 3.51, so the shipped rule would have failed the shipped button.

What changed:

- On a verdict `main` fill, only the stamp word (32 pt) and the icon glyphs may use the `on`
  color at 3:1. Every smaller label on such a fill is `ink`.
- The destructive button label is now `ink` on `trash.main`, measured at 4.61 (row 32).
- The contrast table was split by role instead of by color pair, which is why it grew from 38 rows
  to 41. Rows 20, 22 and 24 carry the stamp word and glyphs at the 3:1 bar; rows 32, 33 and 34 carry
  text on a fill at 4.5; row 40 keeps the white stamp word on tomato at 3.51 and says in the row
  itself that it is never a button label.
- White on cobalt (6.57) clears 4.5 and is unchanged. The yellow exemption is unchanged: it covers
  the yellow *edge*, never text on yellow, which is navy at 10.20.

**Correction, 2026-09-24 (the table is 43 pairs, and every row above 18 moved).** Every row number in
this entry was written against a 41-row table. ADR-023 added two rows for the CTA pill label, at
positions **19** and **20**, so each row previously numbered 19 or higher is now two higher. The
table is **43 pairs, 0 failures**. Read against the current `scripts/out/contrast.md`, this entry's
citations are:

| What the row carries | Cited here as | Now | Ratio |
|---|---|---|---|
| white stamp word and glyphs on `trash.main` | 20 | 22 | 3.51 |
| white stamp word and glyphs on `archive.main` | 22 | 24 | 6.57 |
| navy stamp word and glyphs on `fave.main` | 24 | 26 | 10.20 |
| `fave.main` edge on `canvas`, informational | 30 | 32 | 1.58 |
| `fave.main` edge on a white screenshot, informational | 31 | 33 | 1.58 |
| `ink` on `trash.main`, destructive label and onboarding copy | 32 | 34 | 4.61 |
| white on `archive.main` as text | 33 | 35 | 6.57 |
| `ink` on `fave.main` | 34 | 36 | 10.20 |
| white stamp word on tomato, never a button label | 40 | 42 | 3.51 |
| `surfaceRaised` on `canvas`, informational | 41 | 43 | 1.21 |

The sentence "it grew from 38 rows to 41" stays as written: that is what the split by role did on the
day it happened, and it is still true of that change. The count in force is 43. The three
informational rows are unchanged in kind and are now 32, 33 and 43, and the yellow exemption still
covers the yellow *edge* only, never text on yellow.

One place this entry's rule was being broken has since been fixed, in the guide rather than in the
tokens. `design-system.html` used to set the `on` color as a small label on a `main` fill in its own
color swatch, which is exactly the mistake this correction was written to stop. The swatch's big word
now sits at the 32 pt stamp size, the one size at which an `on` color on a `main` fill is licensed at
3:1, and the small "on" chip moved onto the `soft` tint, where it is a square of the `on` color
beside an `ink` label. Nothing in the guide now sets 14 or 16 pt `on` text on a `main` fill.

**Correction, 2026-09-24 (the swatch, re-checked; and one `on` label the last sentence walks past).**
The correction above ends by describing what the guide's color swatch now does. Checked against
`design-system.html` as it stands, two of its three claims hold and the third is true only by
arithmetic accident.

Holds. The swatch's big word is the stamp word. `.swatch__main` sets `font: var(--t-stamp)` and
`--t-stamp` is `700 32px/1 var(--font-display)`, which is the one size at which an `on` color on a
`main` fill is licensed at the 3:1 large-text bar. `grep -c 'swatch__main' design-system.html` returns
4 on 2026-09-24: the rule plus the three verdict cards that use it. The CSS carries a comment saying
why, so the reason travels with the code.

Holds. The small "on" chip sits on the `soft` tint. Each `.swatch__variants` cell sets the verdict's
`soft` color as its background and `--color-ink` as its text, and `.swatch__onchip` is a 16 px square
filled with the `on` color beside that ink label. No `on` color is text there.

True only by accident. "Nothing in the guide now sets 14 or 16 pt `on` text on a `main` fill." The
guide does set an `on` color as a small label on its own `main` fill: `.gcol.content`, the content
column of the grid visualisation in 10 Grid & Responsive, is `background: var(--color-archive)` with
`color: var(--color-archive-on)` at `font: var(--t-btn-cap)`, which is 12 px. Twelve is neither 14 nor
16, so the sentence is not falsified, and the cell is legal, but not for the reason the sentence
implies. What licenses it is the measurement: white on `archive.main` is 6.57 and clears the 4.5 text
bar on its own, which is why this entry's Decision says cobalt "stays white" and why
`DESIGN_PRINCIPLES.md` P-19 names cobalt as the one measured exception. The size-free rule is the one
to carry forward: an `on` color may label its own `main` fill only where that pair clears the bar its
size demands, which on tomato and on yellow means the stamp word and the glyphs and nothing smaller.

One thing the swatch does not render as intended, in a file this document does not own. The `on` chip
carries `box-shadow: inset 0 0 0 1px var(--color-hairline)`, and `--color-hairline` is declared
nowhere: on 2026-09-24 `grep -c -- '--color-hairline:' design-system.html` returns 0 while
`grep -o 'var(--color-hairline)' design-system.html | wc -l` returns 3. An unresolved `var()` with no
fallback makes the whole declaration invalid at computed-value time, so the shadow is dropped and the
white `on` chips on `trash.soft` and `archive.soft` have no boundary. The chip is still a square of
the `on` color beside an `ink` label, which is what the correction above claimed; it is the hairline
that is missing. Either declare the token or drop the `inset` shadow, in the guide. Note that a
hairline would be the system's only other line, so P-09 makes dropping it the cheaper answer and the
chip then relies on the `soft` tint behind it, which is why this is recorded here rather than fixed by
guess.

## ADR-005 · Monochrome navy accent; no success/error hues

**Decision.** Primary buttons are navy ink (`accent` = `ink`) with white labels; on a color block
the CTA is a navy pill or a white pill. Nothing else in the chrome is saturated, so the three
verdict colors and the expressive blocks own all the color on screen. There are no green
"success" or red "error" tokens: success is a haptic + copy, errors are ink text with the
warning glyph. Red would collide with TRASH.

**Correction, 2026-09-24.** Two sentences in the Decision above are wrong, and they fail in opposite
directions: one offers a choice that should never have been open, the other closes a count that is
one place short.

**"On a color block the CTA is a navy pill or a white pill."** It is not a choice. Since ADR-023 the
pill inverts the block's own ink pair: `DSBlock.ctaFill` is the block's `ink` and `DSBlock.ctaLabel`
is that ink's counterpart. Left as a free choice, a white pill measures 1.15 against `lime`, 1.15
against `fave.soft`, 1.53 against `pink`, 1.79 against `mint` and 2.61 against `lavender`, and a navy
pill measures 2.33 against `violet`. Six of the seven blocks therefore had a wrong answer available
and this sentence licensed it; `trash.main` is the only one where the choice could not go wrong,
clearing the 3:1 non-text bar at 4.61 navy and 3.51 white. The same stale sentence is the doc
comment on `DSColor.accent` (`Sift/DesignSystem/DSColor.swift`) and the caption on the
on-block button demo in section 07 of `design-system.html`, whose demo still puts a white pill on
lavender at 2.61. Both files are outside this document and need the same fix.

**"Nothing else in the chrome is saturated."** That undercounts by one, and the one it misses is the
loudest control in the app. P-06 names four places where a verdict color appears in the chrome: the
stamps, the three verdict buttons, the Trash count badge, and **the destructive button**, which is a
`trash.main` fill with a navy `ink` label at 4.61 (row 34). The accurate sentence is the one P-06
already uses: saturation appears in those four chrome places plus the full-bleed blocks, and
everywhere else the app is white and navy. The guide repeats the undercount verbatim on its
`accent / onAccent` card, which is the same fix in a file this document does not own.

Neither correction touches what this entry decided. The accent is still `ink`, primary buttons are
still navy pills with white labels, and there are still no green success or red error tokens: success
is a haptic plus a sentence, an error is navy text with the warning glyph, and red would collide with
TRASH.

**Correction, 2026-09-24 (both files named above have been fixed, and the line number is withdrawn).**
The correction above ends by saying the stale sentence "is the doc comment on `DSColor.accent`
[...] and the caption on the on-block button demo in section 07 of `design-system.html`, whose demo
still puts a white pill on lavender at 2.61", and that "both files are outside this document and need
the same fix". Both have been fixed. The elision is a line number that used to sit inside that
parenthesis and was struck on 2026-09-24 under the rule against citing line numbers in another file;
it had already stopped locating the comment.

- `DSColor.accent`'s doc comment states the rule instead of the retired choice. It now says that on a
  color block the CTA "is NOT a free choice between this and a white pill", that it is
  `DSBlock.ctaFill`, the block's own ink, and it carries the two ratios that close the choice.
  `grep -n 'ctaFill' Sift/DesignSystem/DSColor.swift` finds it; the withdrawn line number does not,
  and no line number replaces it.
- The guide's on-block demo puts a navy pill on lavender, not a white one. `.btn--onblock` is
  `background: var(--color-ink)` with `color: var(--color-on-accent)`, and `.onblock-demo` is
  `background: var(--color-lavender)`. Its caption now opens "The pill is never a free choice between
  navy and white" and names the two retired ratios as retired.
- The undercount is fixed too. The guide's `accent / onAccent` card now reads "Saturation in the
  chrome is limited to four places: the three stamps, the three verdict buttons, the Trash count
  badge, and the destructive fill (ADR-005). A color block is not chrome." That is P-06's count.

Nothing this entry decided moves. What changes is the status of the two follow-ups it recorded: they
are done, and a correction that keeps pointing at a repaired defect sends the next reader looking for
something that is already right.

## ADR-006 · Light only, white canvas; elevation and layering inherited from the reference system

**Context.** The first plan was dark-first with adaptive tokens. After seeing three mock-ups
(light color-block with system dark, dark-first, light-only) the owner chose light-only, then
asked for a plain white background instead of cream.

**Decision.** One color scheme. `canvas` and `surface` are both pure white; the root view pins
`.preferredColorScheme(.light)`. Surfaces separate by tint (`surfaceRaised`, light gray) and by
whitespace, never by borders — the focus ring is the only line. Shadows exist only on floating
things (front card, committed stamp, verdict buttons, toast, sheets) and are the reference's two
soft layers: `0 1 3 · ink 10 %` + `0 10 24 −6 · ink 5 %` (`DSShadow.floating`) and its upward
twin for stacked cards (`DSShadow.stack`). Layering uses the reference z ladder
(`DSLayer`: sticky 100 · dropdown 1000 · modal 2000 · toast 3000).

**Consequences.** Half the tokens of an adaptive system; no dark contrast table. A dark
screenshot on the white canvas separates by its own edge and the card shadow. Users who run iOS
in dark mode see a light app — accepted trade-off, recorded here.

## ADR-007 · Haptic vocabulary: impact weight encodes direction

**Decision.** A verdict is an `.impact`, a completed success is `.success`, a destructive
confirmation is `.warning` (rule inherited from the previous app). Weight encodes direction so
eyes-off swiping still confirms which verdict landed: TRASH heavy, ARCHIVE medium, FAVE two
light pulses 90 ms apart. Threshold crossing is `.selection` (rising edge only); snap-back and
the down dead zone are silent. Everything goes through `.dsHaptic(_:trigger:)`.

## ADR-008 · Undo is a single-step rewind

**Decision.** One "rewind" button restores the last card only, reversing the side effect to the
*recorded prior state* (a heart is un-set only if it was off before). Deeper mistakes are
handled by Trash (restore) and Library (move). History survives navigating to Trash / Library
within a session and is cleared on cold launch.

## ADR-009 · Permanent deletion always goes through the iOS dialog; "delete all" gets an in-app sheet first

**Context.** PhotoKit's `deleteAssets` always presents a system confirmation that cannot be
suppressed; a batch presents one dialog.

**Decision.** Ladder by *recoverability after confirm*:

| Rung | Actions | Confirmation | Haptic |
|---|---|---|---|
| 0 | swipe and button verdicts, viewer Trash, Library moves, Restore | none; Trash and rewind are the net | verdict `.impact`, restore `.success` |
| 1 | Delete permanently, one item | the iOS dialog is the one confirmation | `.warning` → `.success` |
| 2 | Delete all permanently | in-app sheet with count and size, then the iOS dialog | `.warning` → `.success` |

At rung 2 the in-app sheet comes first and names both numbers: `PurgeAllSheet` carries the title
`"Delete 27 screenshots permanently?"`, the body `"They leave \(Brand.name) for good and go to
Photos' Recently Deleted for 30 days. iOS will double-check — that's expected."`, and the buttons
`"Delete 27 permanently"` and `"Keep them"`. The body pre-announces the second dialog so the double
confirmation reads as designed rather than as a bug. Only after the sheet dismisses does
`DSHaptic.purgeArmed` fire and `deleteAssets` present the system dialog. Cancelling that dialog leaves
Trash untouched and posts the toast `"Not deleted"`. `UI_DESIGN.md` §11.3 and section 07 of
`design-system.html` describe the same two steps in the same order.

**Correction, 2026-09-24.** Rung 2's Confirmation cell reads "in-app sheet with count and size", and
the paragraph under the ladder says the sheet "names both numbers". The sheet names one number. Its
three strings carry the count three times and the size never: the title is
`"Delete 27 screenshots permanently?"`, the body names no number, and the buttons are
`"Delete 27 permanently"` and `"Keep them"`. The size is carried by the control that raises the
sheet, the docked destructive button `"Delete all permanently (27 · 48 MB)"`, and by the Trash
header, `"Trash · 27 items · 48 MB"`. Both are in `UI_DESIGN.md` §11.3, which is the document this
entry claims to agree with, and both are rendered in section 07 and section 09 of the guide.

The wording that matches all three is **"in-app sheet naming the count, then the iOS dialog"**, with
the size named by the destructive button that raises the sheet. Nothing else in the ladder moves:
rung 2 is still two confirmations in that order, the body still pre-announces the second one, and
`DSHaptic.purgeArmed` still fires only after the sheet dismisses.

Section 07 of `design-system.html` carries the same error in its rung caption, which says the sheet
"names the count and the size" while the sheet mock-up immediately above it shows a title, a body and
two buttons with no size in any of them. That file is outside this document; the caption needs the
same fix there.

**Correction, 2026-09-24 (rung 2's wording, settled; and the guide's caption, in two places).** The
correction above gives the wording that matches the code and `UI_DESIGN.md` §11.3: **"in-app sheet
naming the count, then the iOS dialog"**, with the size named by the destructive button that raises
the sheet. That is the wording in force for rung 2's Confirmation cell. The cell still reads "in-app
sheet with count and size" because a correction in this log never rewrites the entry it corrects; the
cell is the record of what was written, and the paragraphs under the ladder are the record of what is
true.

§11.3 is the check and it agrees. Its "Purge all" block lists the sheet's three strings and no size
appears in any of them: the title `"Delete 27 screenshots permanently?"`, the body that pre-announces
the iOS dialog, and the buttons `"Delete 27 permanently"` and `"Keep them"`. The size is on the two
controls around the sheet, the docked `"Delete all permanently (27 · 48 MB)"` and the Trash header
`"Trash · 27 items · 48 MB"`.

The guide does not agree yet, and it carries the error in **two** sections rather than the one the
correction above named. `grep -c 'names the count and the size' design-system.html` returns 2 on
2026-09-24. The first is in 01 Principles, in the recoverability card, which says deleting everything
"adds an in-app sheet that names the count and the size first". The second is the rung caption in 07
Interaction & Motion, sitting immediately under a `.sheet-mock__sheet` that shows a title, a body and
two buttons with no size in any of them. In both, the clause should read "names the count", and the
size stays with the docked destructive button, which the same page already renders twice, in 07 and
again in 09 Screens. That file is outside this document.

## ADR-010 · Limited photo access is a first-class state

**Decision.** Permission is requested only on tap, never on launch. Limited access gets an
interstitial ("You picked 14 screenshots. Sift only sees those.") with "Pick more"
(`presentLimitedLibraryPicker`) and "Sift these 14". Denied gets "Open Settings". If PhotoKit
refuses album writes under limited access, Archive falls back to an app-local list and Library
renders either source. To verify on device in the app phase.

**Correction, 2026-09-27.** The Decision above calls the app-local list a fallback that exists only
when PhotoKit refuses the album write. Since ADR-025 (A4, confirmed by the owner on 2026-09-27) the
list is the truth on every path and the album is its mirror. Under limited access nothing falls
back: the verdict is recorded in the list as always, only the mirror write is skipped, and the album
catches up when access widens. Library renders the list, never the album. What still needs a
device check is only whether the mirror write is refused at all.

## ADR-011 · Navigation by header icon buttons, no tab bar

**Decision.** Review is the root. Trash (with count badge) and Library are icon buttons in the
Review header that push onto a `NavigationStack`. A tab bar would take 83 pt from the card and
imply three equal destinations; the card is the product.

## ADR-012 · No sound in v1

**Decision.** v1 has no settings screen, so a sound that cannot be turned off would be a defect.
Haptics carry the game feel. If added later: short custom samples, `.ambient` category, opt-in.

## ADR-013 · Stamps read TRASH / ARCHIVE / FAVE and are pills

**Context.** Each word names the destination the user can find later (Trash screen, the
"Archive" album in Photos, Photos ♥). "Delete" is reserved for the irreversible action, so the
swipe word is TRASH. FAVE fits at stamp size; VoiceOver still says "Favorite".

**Decision.** Pill labels (`DSRadius.pill`), `main` fill, `on` word in Forager Bold Overlap 32
(cap 44), uppercase, tracking +2, the verdict glyph leading, `DSShadow.floating`. The stamp word is
the one text that uses `on` at the 3:1 bar rather than `ink` (ADR-004), because at 32 pt it is WCAG
large text. The cap is enforced outside Dynamic Type's own scaling: the call site scales
`DSTextRole.stampBaseSize` with `@ScaledMetric(relativeTo: .largeTitle)` and hands the result to
`DSTextRole.stampFont(size:)`, which applies `min(size, stampMaxSize)` and returns a fixed-size
font — so the cap holds at accessibility sizes and the value is never scaled twice. That makes
`stamp` the one `DSTextRole` case not bound to a Dynamic Type text style through `relativeTo:`; the
other ten are. Solid fill,
not outline: screenshots are usually white and an outline vanishes. Placement: TRASH top-right
rotated +12°, ARCHIVE top-left −12°, FAVE centred slightly above middle, 0°. The stamp's opacity
ramp ends exactly at the commit distance, so a fully opaque stamp *is* the "release will commit"
signal.

The face named here changed on 2026-09-24, from Acme Gothic Black to Forager Bold Overlap
(ADR-003's correction). Nothing else in this entry moved: the 32 pt base, the 44 pt cap, the +2 pt
tracking, the pill, the leading glyph and the three placements are unchanged, and no contrast row
shifts, because the stamp word clears the WCAG large-text bar on its size, not on its weight.

## ADR-014 · The archive album is named "<Brand> Archive"

**Decision.** `Brand.archiveAlbumTitle` = "\(Brand.name) Archive". A prefixed name keeps the
album recognisable next to the user's own albums and survives a rename through ADR-002.

## ADR-015 · Trash has no multi-select

**Decision.** Two granularities — one item, or all — cover a holding pen. Selection mode would
add a toolbar and edge cases for little gain in v1.

## ADR-016 · Typographic faces on expressive color blocks

**Context.** The second reference board builds faces out of letterforms on flat color tiles.

**Decision.** Empty states and onboarding are full-bleed color blocks carrying one typographic face
(`DSFace`), built from type alone. No image assets. `DSBlock` fixes the mapping for its
seven cases: onboarding → `trash.main`, all done → `lime`, trash empty → `mint`, favorites empty →
`pink`, archive empty → `lavender`, denied → `violet` (white ink), limited → `fave.soft`. The guide
renders the six blocks that are not the hero; onboarding appears as the hero block itself.

The expressive colors never carry verdict meaning and verdict colors never serve as blocks — with
**two** deliberate exceptions, both of them a verdict color borrowed for a screen that precedes or
sits outside any verdict:

1. **Onboarding is `trash.main`** (tomato), because the reference hero is tomato and onboarding
   happens before the user has made a single verdict.
2. **The limited-access interstitial is `fave.soft`** (pale yellow), because it is a notice about
   what the app can see, not a state of an asset. `soft` is a tint, never a stamp or button fill, and
   the copy on it is `ink` at 14.01.

Neither exception runs the other way: an expressive color never means a verdict. Any third exception
has to be recorded here, with the reason, before it ships.

**Correction, 2026-09-24.** This entry used to say the blocks carry "a two-line face set in the
display face (`DSFace`: eyes over mouth)". A face is neither two lines nor entirely set in the display
face.

A face is ONE glyph borrowed from a world script, framed by round parentheses. The parentheses are the
head; the glyph is the eyes and the mouth at once, so a face occupies a single line. `DSFace` has
seven cases, one per `DSBlock`, and no glyph is used twice:

| Case | Glyph | Origin | Block |
|---|---|---|---|
| `eager` | ᐛ | U+141B CANADIAN SYLLABICS NASKAPI WAA | `onboarding` |
| `delighted` | ஶ | U+0BB6 TAMIL LETTER SHA | `allDone` |
| `breezy` | ツ | U+30C4 KATAKANA LETTER TU | `trashEmpty` |
| `soft` | ω | U+03C9 GREEK SMALL LETTER OMEGA | `favoritesEmpty` |
| `blank` | ఠ | U+0C20 TELUGU LETTER TTHA | `archiveEmpty` |
| `tearful` | ಥ | U+0CA5 KANNADA LETTER THA | `denied` |
| `quizzical` | ѹ | U+0479 CYRILLIC SMALL LETTER UK | `limited` |

`DSFace` exposes `glyph`, `origin` (the Unicode name, so nobody has to guess where a letter came
from), the static `open` and `close` brackets, and `text`, the whole face as one string for a preview
or a snapshot test.

Only the brackets come from the display face. Each centre glyph is drawn by whichever system font
carries its script, so a face pairs a heavy Latin bracket with a lighter non-Latin letter. That weight
contrast is the intended look, and it is also why a face never carries information: faces stay
`accessibilityHidden`, and the headline under the block says what happened.

The previous five-case set (`hello`, `delighted`, `relieved`, `waiting`, `sorry`) is gone. Only the
name `delighted` survives, now carrying a different glyph. Gone with it is the mapping that stretched
five faces across seven blocks by reusing `waiting` and `sorry`. Seven blocks now have seven distinct
faces. The block-to-color mapping above is unchanged.

## ADR-017 · Icons from the Noun Project, bold solid, CC BY credits

**Decision.** ~12 glyphs, bold solid style, sourced from thenounproject.com on the free plan
(CC BY). Each shipped icon needs a credit line ("<title> by <author> from Noun Project"), so the
app carries a credits screen fed by `DSIconCredits.entries` and reachable from the onboarding
footer. Until an asset is dropped into the catalog, `DSIconRef.image` falls back to an SF Symbol
so the app runs; the fallback is development scaffolding, not a shipping state. Icons are
template images that inherit color; never a filled tile behind a glyph.

## ADR-018 · Spacing, radius and grid inherited verbatim from the reference system

**Decision.** Spacing `6 · 8 · 12 · 16 · 24 · 28 · 32` (`DSSpace.s1–s7`); radius `xs 6 · sm 8 ·
md 12 · lg 16 · xl 24 · pill` where a radius tracks the element's inner padding and nested
radius = outer − gap; grid with a single 1200 px breakpoint — desktop 14 columns (ends are
margins, content in 2–13, gutter 24) for the style guide, mobile 4 columns (margin 16, gutter 8)
for the app. Reason: proven in the owner's previous system and the guide format is the same.

## ADR-019 · Swipe physics: four 90° sectors, 120 pt / 800 pt·s⁻¹ commit

**Decision.** θ = atan2(−dy, dx): ARCHIVE (−45°, 45°], FAVE (45°, 135°], TRASH (135°, 225°],
DOWN dead zone (225°, 315°] with 6° hysteresis. Commit at 120 pt of travel *or* 800 pt/s along
the sector axis after at least 48 pt. Rotation dx/20 clamped ±12°; exit 720 / 840 pt with a
velocity-derived duration clamped to 0.18–0.32 s; side effect and promotion at 60 % of the exit.
Reasons: four equal quadrants are one rule to learn; 120 pt is a third of the card; 800 pt/s is
a deliberate flick; the velocity floor kills tap-drags. Values live in `DSSwipe` and `DSMotion`.

## ADR-020 · Documentation in English; the HTML guide mirrors the reference format

**Decision.** `UI_DESIGN.md` and `design-system.html` are written in English for course
submission. The HTML follows the owner's reference guide: sticky sidebar nav, colored hero, eleven
numbered sections, scroll-spy, one breakpoint. The sections, in the order the page and its sidebar
carry them, with the anchor ids other documents link to:

| # | Section | Anchor |
|---|---|---|
| 01 | Principles | `#principles` |
| 02 | Color | `#color` |
| 03 | Typography | `#type` |
| 04 | Spacing & Radius | `#spacing` |
| 05 | Icons | `#icons` |
| 06 | Elevation & Layering | `#elevation` |
| 07 | Interaction & Motion | `#motion` |
| 08 | Swipe Deck | `#swipe` |
| 09 | Screens | `#screens` |
| 10 | Grid & Responsive | `#grid` |
| 11 | Checklist | `#checklist` |

Sections 08 Swipe Deck and 09 Screens carry what is specific to this app: the sector map and the
physics demo, then the four screens, the viewer bar and the six rendered color blocks with their
faces. The breakpoint is `--grid-breakpoint`, 1200 px, written into the stylesheet as twelve
`max-width: 1199.98px` queries (ADR-022).

**Correction, 2026-09-24.** This entry used to list the sections as "principles → color → type →
spacing & radius → icons → elevation → motion → card stack → grid → checklist" plus "the sections this
app adds (swipe demo, screens, faces, credits)". That is fourteen names for eleven sections, and three
of the names are not on the page. Neither "card stack" nor "swipe demo" is a section: the deck has
one section and it is 08 Swipe Deck. There is no "faces" section and no "credits" section either: the
seven faces and their code points close 09 Screens, and the Noun Project credit block sits inside
05 Icons. The table above is read off the `<section>` ids and the sidebar list in
`design-system.html`.

**Correction, 2026-09-24 (what actually closes 09 Screens).** The correction above says "the seven
faces and their code points close 09 Screens". The code points are not there. Checked in the current
file: 09 Screens ends with the six rendered blocks and one caption, and that caption names the seven
**scripts** and then defers every code point to the Swift token, reading "each listed with its code
point in `DSFace.origin`". The page prints the glyphs as HTML character references and prints no
`U+` anywhere in any section.

The seven `U+` names live in `DSFace.origin` (`Sift/DesignSystem/DSIllustration.swift`) and in
ADR-016's correction table in this document. So the honest sentence is: the seven faces
close 09 Screens, named by script rather than by code point, each code point deferred to
`DSFace.origin`. That deferral is deliberate and matches ADR-001, which keeps the Swift file
canonical and the guide derived. Everything else in the correction stands, including the point it was
making: there is no "faces" section and no "credits" section.

**Correction, 2026-09-24 (the `U+` names, located without a line span).** The correction above located
the seven `U+` names by naming `DSFace.origin` and then adding a line span inside the parenthesis.
That span is struck: the file was edited after it was written, and a line range in another file is a
claim that decays. The stable locator is the property itself, `DSFace.origin`, and the count is what the
correction was actually using the span for. Counted on 2026-09-24:
`grep -c 'U+' Sift/DesignSystem/DSIllustration.swift` returns **7**, one per `DSFace` case, and
`grep -c 'U+' design-system.html` returns **0**, which is the point being made. Everything else in
that correction stands: 09 Screens ends with the six rendered blocks and one caption, the caption names
the seven scripts and defers each code point to `DSFace.origin`, and there is no "faces" section and no
"credits" section.

## ADR-021 · The focus ring is `ink` at 60 %, not 45 %

**Context.** `DSColor.focus` was `ink.opacity(0.45)`, picked by eye to match the light ring in
the reference guide. Composited over `canvas` that measures **2.79:1** — below the 3:1 bar WCAG sets
for a non-text indicator — and the contrast table had no row for it at all. In a system with no
borders the ring is the only stroke (P-09), so it was the one visual element nothing was checking.

**Options.** (a) Keep 45 % and declare the ring decorative, exempt like the yellow edge. (b) Raise
the alpha until the composite clears 3:1 on every surface a focusable control can sit on. (c) Use
solid `ink`.

**Decision.** (b). `DSColor.focus = ink.opacity(0.60)`, width unchanged at `DSSize.focusRing` = 3.
Two rows now cover it and both are enforced at the 3:1 non-text minimum: `focus` over `canvas`
measures **4.34** (row 16) and `focus` over `surfaceRaised` **4.06** (row 17).

Option (a) was rejected because a focus ring reports state — where the keyboard is — and state is
never decoration; the yellow exemption works only because the word and glyph carry the same meaning,
and a ring has no word. Option (c) was rejected because solid ink reads as a border, and P-09 keeps
borders out of the system.

**Consequences.** The ring is denser than the reference's; that is a deliberate departure, not a
drift. Because the ring is translucent, its ratio depends on what it sits on, so a new surface token
needs its own `focus`-over-surface row in `PAIRS` before it may host a focusable control.

**Correction, 2026-09-24.** The Decision above describes option (b) as raising the alpha "until the
composite clears 3:1 on every surface a focusable control can sit on", and then verifies exactly two
surfaces. Two rows are not every surface. A focusable control also sits on a color block: the CTA
pill, on all seven `DSBlock` fills. Composited over those, `ink` at 60 % measures 2.65 on
`trash.main`, 3.51 on `mint`, 3.71 on `pink`, 4.20 on `lime`, 4.15 on `fave.soft`, 2.92 on
`lavender` and 1.71 on `violet`. Three of the seven are under the 3:1 non-text bar, so the sentence
was false on the day it was written, and false for the same reason this entry exists: a surface
nothing had measured.

The alpha is unchanged and both of its rows still pass. 60 % is right for the neutral surfaces it was
chosen for; what was wrong is the scope claimed for it. On a block the ring is not `DSColor.focus` at
all, it is `DSBlock.focusRing`, the block's own ink at full strength, which lands on the pair the
block's copy already clears at the stricter text bar (ADR-023). The accurate statement is this:
`DSColor.focus` clears 3:1 on the two neutral surfaces measured in rows 16 and 17, and a focusable
control on any other surface needs its own row, or its own ring token, before it ships. The
Consequences paragraph below already required the first half of that. It did not say that a color
block was such a surface, and nothing pointed at the seven that already existed.

**Correction, 2026-09-24 (the ring color is a parameter now, so "its own row" is one of two ways out).**
The Consequences above say that because the ring is translucent, "a new surface token needs its own
`focus`-over-surface row in `PAIRS` before it may host a focusable control". That was the only route
available while the ring color was fixed inside the helper. It is not the only route any more.
`View.dsFocusRing` takes the color:

```swift
func dsFocusRing(_ focused: Bool, cornerRadius: CGFloat, color: Color = DSColor.focus) -> some View
```

`DSColor.focus` is the default, so every call written before this reads the same and behaves the same,
and a control that sits somewhere `focus` was never measured passes its own ring instead. That is
precisely what a control on a color block does: it passes `DSBlock.focusRing`, the block's ink at full
strength (ADR-023).

So the accurate Consequence has two branches. A new surface may host a focusable control when either
(a) `DSColor.focus` composited over that surface has a row in `PAIRS` at the 3:1 non-text minimum,
which today means `canvas` at 4.34 and `surfaceRaised` at 4.06 and nothing else, or (b) the control
passes a ring color that is opaque and already measured against that surface, which is what the seven
blocks do without adding any row, because the block's ink on the block is the same pair the block's
copy clears at the stricter 4.5 text bar. What stays forbidden is the case the Consequences were
written to forbid: a focusable control on a surface where neither the default ring nor a passed one
has been measured. The doc comment on `dsFocusRing` states that in one sentence, that anything drawn
on a surface with no measured focus row has no business hosting a focusable control.

The **Applies to** line below names the modifier as `.dsFocusRing(_:cornerRadius:)`. Its declared name
is now `.dsFocusRing(_:cornerRadius:color:)`. The two-label form is still a legal call site because
`color` defaults, so the line is not wrong about how the helper is called, but it no longer spells the
declaration. ADR-002's modifier inventory carries the same two-label form and the same qualification.

**Applies to** `DSColor.focus`, `DSSize.focusRing`, `.dsFocusRing(_:cornerRadius:)`, P-09, P-19.

## ADR-022 · The token script fails loudly; CSS-variable usage is counted exactly

**Context.** Three ways for the generated layer to look healthy while being wrong. First, a
color or numeric declaration whose shape the regexes did not match was skipped in silence, so a
token could disappear from the contrast table and from the CSS without any output changing.
Second, variable usage was counted by substring, so a prefix satisfied its own extensions
(`--color-trash` was "used" by `--color-trash-soft`, `--size-fave-button` by
`--size-fave-button-raise`) and a mention inside an HTML comment counted as a real use. Third, a
variable the guide declares but has no way to consume was either an unexplained lint failure or a
silent pass, depending on how the check was phrased.

**Options.** (a) Leave it and rely on review to notice. (b) Harden the three spots in
`ds_tokens.py`. (c) Replace the script with a token build tool — already rejected in ADR-001.

**Decision.** (b), in three parts.

1. **A declaration that does not parse aborts the run.** `parse_colors` counts the `static let`
   declarations it found (three for a `VerdictColorSet`) against the tokens it produced and exits
   with the missing names; `parse_numbers` exits on any `static let name: CGFloat | Double | Int`
   line it cannot read. A refactor that changes how a token is written now stops the toolchain
   instead of shrinking the table.
2. **Usage is counted by exact name, outside comments.** The lint strips `<!-- ... -->` from the HTML
   first, then matches each variable with a trailing-character guard, and requires two occurrences:
   the declaration in the generated `:root` block plus at least one real use.
3. **Declaration-only variables are allowlisted with a reason, and printed every run.**
   `DECLARATION_ONLY` holds exactly three: `--grid-breakpoint` (CSS media queries cannot take
   `var()`, so every `@media` rule spells the breakpoint literally), `--motion-dur3` (surface
   transitions — the guide has no animated sheet) and `--motion-toast-visible` (the toast demo is a
   static swatch, so nothing counts down 2.5 s). Each prints a `lint: EXCEPTION` line on every run.

**Consequences.** `lint` exits 0 while printing three EXCEPTION lines, plus one WARNING line until
the Noun Project credits land (ADR-017). "Clean" therefore means `lint: OK` on the last line, not an
empty output — a reader who treats any printed line as a failure will misread a passing run. The
verification set is **four** commands: `contrast`, `emit-css`, `lint`, `typecheck-ds.sh`. Adding a
variable to `DECLARATION_ONLY` is a decision, not a fix: it needs a reason in the dictionary and it
stays visible in the output.

**Correction, 2026-09-24.** The reason recorded for `--grid-breakpoint` used to read "CSS media
queries cannot take `var()`, so the two `@media` rules repeat 1200 px literally". The premise is
right and both numbers in it are wrong. Counted in `design-system.html` on 2026-09-24. (The first row
listed those twelve line numbers until 2026-09-24, and the third named a line for the declaration; both
were struck under the rule against citing line numbers in another file, and the 2026-09-24 correction
at the end of this entry carries the commands that return the counts instead.)

| What | Count | Where |
|---|---|---|
| `@media (max-width: 1199.98px)` blocks | 12 | spread through the stylesheet, one per responsive rule, from 02 Color to 10 Grid & Responsive |
| All other `@media` blocks | 3 | two `(hover: hover) and (pointer: fine)`, one `(prefers-reduced-motion: reduce)` |
| The literal `1200px` | 1 | the `--grid-breakpoint: 1200px` declaration in the generated `:root` block |

So it is twelve rules, not two, and they spell **1199.98px**, not 1200 px: a `max-width` query has to
stop just below the breakpoint, or 1200 px would match the desktop rule and the narrow rule at once.
The only other place the string `1200px` appears is the CSS comment introducing the desktop
`DSTextRole` block, which the lint strips before counting. None of this weakens the allowlist entry: the variable is still declaration-only for
exactly the reason given, and recording that reason is what `DECLARATION_ONLY` is for.

The same stale sentence is still the value of `"--grid-breakpoint"` in `DECLARATION_ONLY`
(`scripts/ds_tokens.py`), so it prints on every `lint` run. That file is outside this
document; the string needs the same fix there.

**Correction, 2026-09-24 (the script string was fixed).** The paragraph above ends by saying the
stale sentence "is still the value of `"--grid-breakpoint"` in `DECLARATION_ONLY`
(`scripts/ds_tokens.py`), so it prints on every `lint` run". It is not, and it does not.
The string now reads "CSS media queries cannot take var(); the guide's twelve max-width queries spell
1199.98px literally", and that is what a `lint` run prints. This paragraph also gave the string's new
line number; that number, and the old one it corrected, were struck on 2026-09-24 and are not replaced,
because the string itself is the locator. The correction outlived the defect it recorded, which is its
own kind of wrong number: a reader following it would have gone looking for a string that is already
right.

**Correction, 2026-09-24 (every line citation in this entry is withdrawn).** This entry used to locate
the twelve `max-width` queries by line number, the `--grid-breakpoint` declaration by a second, and a
CSS comment by a third. Its first correction then gave the `DECLARATION_ONLY` string a line number, and
its second correction updated that number rather than dropping it. The string has since moved again.
That is four rounds of citation for one defect inside a single entry, and three of those rounds had
already gone wrong by today. The defect is the citation form, not the arithmetic: a line number in
another file is wrong as soon as that file is edited. All of those numbers are struck above and
replaced by a section, a selector or a string. None is replaced by a newer number, because a newer
number would be the fifth round.

The counts were right every time, so the counts are what this entry keeps, each with the command that
returns it. Run from the repository root, plain `grep`, basic regex, all counted 2026-09-24:

| What | Command | Result |
|---|---|---|
| breakpoint queries | `grep -c '@media (max-width: 1199\.98px)' design-system.html` | 12 |
| every `@media` rule | `grep -c '@media' design-system.html` | 15 |
| the string `1200px` | `grep -c '1200px' design-system.html` | 2 |
| the corrected allowlist reason | `grep -c 'twelve max-width queries spell 1199.98px literally' scripts/ds_tokens.py` | 1 |

Twelve breakpoint queries out of fifteen `@media` rules, so three are something else: two
`(hover: hover) and (pointer: fine)` and one `(prefers-reduced-motion: reduce)`, which belongs to
ADR-024. Of the two `1200px` strings, one is the `--grid-breakpoint` declaration in the generated
`:root` block and the other is a CSS comment that the lint strips before counting, which is why the
variable still reads as declaration-only and the allowlist entry still earns its place. The reason
string in `scripts/ds_tokens.py` is the corrected one and prints on every `lint` run; find it by the
string, never by a line number.

**Applies to** `scripts/ds_tokens.py`, `scripts/typecheck-ds.sh`, ADR-001, P-12, P-19, P-23.

## ADR-023 · The CTA pill and the focus ring on a color block are the block's own ink

**Context.** ADR-005 left the call to action on a full-bleed color block as a free choice, "a navy
pill or a white pill", picked by eye per block. ADR-021 raised `DSColor.focus` to `ink` at 60 % and
measured it on two surfaces. Neither rule had ever been measured against the seven `DSBlock` fills,
which are the most saturated surfaces in the system and the only ones a CTA and a focus ring share.
Measured with the project's own script, both rules fail on real blocks: a white pill is invisible as
a shape on five of the seven, a navy pill on the sixth, and the 60 % ring drops under the 3:1
non-text bar on three.

| Block | Fill | Ink | Pill filled with the block's ink | A white pill on the block | `focus` at 60 % over the block |
|---|---|---|---|---|---|
| `onboarding` | `trash.main` | `ink` | 4.61 | 3.51 | 2.65 FAIL |
| `allDone` | `lime` | `ink` | 13.99 | 1.15 | 4.20 |
| `trashEmpty` | `mint` | `ink` | 9.02 | 1.79 | 3.51 |
| `favoritesEmpty` | `pink` | `ink` | 10.56 | 1.53 | 3.71 |
| `archiveEmpty` | `lavender` | `ink` | 6.18 | 2.61 | 2.92 FAIL |
| `denied` | `violet` | `onAccent` | 6.95 | white *is* the ink pill here; a navy pill measures 2.33 | 1.71 FAIL |
| `limited` | `fave.soft` | `ink` | 14.01 | 1.15 | 4.15 |

**Options.** (a) Keep the free choice and pick the readable pill per block by eye. (b) Derive both
the pill and the ring from the block's own ink pair, so neither is a choice. (c) Give the pill a
border or a shadow so a white pill survives on lime.

**Decision.** (b), in two parts.

1. **The pill inverts the block's ink pair.** `DSBlock.ctaFill` is the block's own `ink`, and
   `DSBlock.ctaLabel` is that ink's counterpart: `DSColor.onAccent` on the six blocks whose ink is
   `ink`, and `DSColor.accent` on `denied`, the one block whose ink is `onAccent`. The pill then
   clears **4.61** at worst (tomato) and **14.01** at best (pale yellow) against its own block, on
   all seven, and the label clears **16.16** on the pill in both directions (rows 19 and 20).
2. **`DSBlock.focusRing` is the block's ink at FULL strength, not `DSColor.focus`.** `focus` is `ink`
   at 60 %, tuned for the neutral surfaces of ADR-021; composited over a saturated block it falls to
   2.65 on tomato, 2.92 on lavender and 1.71 on violet, all under the 3:1 bar WCAG sets for a
   non-text indicator. At full strength the ring is the same pair the block's own copy already
   passes, 4.61 at worst.

Option (a) was rejected because "pick the readable one" is not a rule a reviewer can check or a
script can measure, and the five failures above are what it actually produced. Option (c) was
rejected on P-09, which keeps borders out of the system, and on ADR-006, which gives shadows only to
things that float; a flat color block does not float.

**Consequences.** The pill and the ring are derived, so adding a block adds no new decision: its
`ink` fixes both. A block whose ink does not clear 4.5 against its own fill is not a legal block,
which the block-copy rows already enforce.

Note what this did **not** add to the contrast table. The pill against its block and the ring against
its block are both the pair "the block's ink on the block", which rows 27, 34 and 37 through 41
already enforce at the stricter 4.5 text bar, so neither needed a row of its own. Two rows were added for the pill **label**, which
is a new pair: `onAccent` on `ink` (row 19) and `accent` on `onAccent` (row 20), both 16.16. That is
what took the table from 41 pairs to **43 pairs, 0 failures**, three of them informational. Because
the two new rows sit at 19 and 20, every row previously numbered 19 or higher moved down by two; the
citations written before that are corrected in ADR-004.

**Correction, 2026-09-24 (a block carries ONE filled action).** The Decision above derives two things
from a block's ink, the pill and the ring, and the Consequences say "adding a block adds no new
decision: its `ink` fixes both". There is a third thing on a block that the same measurement governs,
and "both" leaves it out: the block's second action.

A block carries **one** filled action. A second action on the same block is bare text in the block's
ink, underlined, with no fill. The reason is the measurement that killed the free choice above. A
filled secondary is a shape, and a shape on a block needs its own 3:1 non-text row against all seven
fills; the obvious candidate, `surfaceRaised`, measures **2.16** against `lavender`, so it fails before
it ships. With no fill there is no shape to measure. What is left is the label, and the label is the
block's ink on the block, which is the pair the block's own copy already clears at the stricter 4.5
text bar. Nothing new enters `PAIRS`, for the same reason the pill and the ring added nothing.

The 2.16 is not in `contrast.md`, because a fill that is never used needs no row. Derive it from the
Swift tokens with the project's own module rather than taking it on trust, from the repository root:

```
python3 -c "import sys; sys.path.insert(0,'scripts'); import ds_tokens as t; T=t.parse_colors(); f=lambda n:t.oklch_to_srgb(T[n].L,T[n].C,T[n].H)[0]; print('%.2f' % t.contrast(f('surfaceRaised'), f('lavender')))"
```

In the guide the rule is `.btn--onblock-text`: `background: none`, `color: inherit`, underlined with a
3 px offset, so it takes the block's ink from whatever block it sits on. The on-block demo shows the
pair it is meant to be read as, one filled `.btn--onblock` beside one `.btn--onblock-text`, and the CSS
carries the 2.16 and the reason as a comment so they travel with the code.

**Correction, 2026-09-24 (implemented in Swift and in the guide, except the ring half of the guide).**
This entry was written as a decision. Both of its parts are code now, and the measurements can be read
off two places instead of one, which is worth recording because the two places disagree in the second
decimal and the disagreement is not an error.

In Swift: `DSBlock.ctaFill` returns the block's `ink`; `DSBlock.ctaLabel` returns `DSColor.onAccent` on
the six blocks whose ink is `ink` and `DSColor.accent` on `denied`; `DSBlock.focusRing` returns the
block's `ink` at full strength. In the guide: `.btn--onblock` is `background: var(--color-ink)` with
`color: var(--color-on-accent)`, a navy pill with a white label, shown on `.onblock-demo`, which is
`background: var(--color-lavender)`; and `.btn--onblock-inverted` is the reverse, covering violet, the
one block whose ink is white.

| Pair | From the OKLCH tokens, `scripts/out/contrast.md` | From the hex the CSS carries |
|---|---|---|
| navy pill against `lavender` | 6.18, row 40 | 6.15 |
| the white label on that pill | 16.16, row 19 | 16.14 |
| white pill against `violet` | 6.95, row 41 | 6.97 |
| the navy label on that pill | 16.16, row 20 | 16.14 |

Neither column is wrong. `scripts/ds_tokens.py` contrasts the unrounded OKLCH-to-sRGB floats; a browser
contrasts the 8-bit hex in `scripts/out/tokens.css`, which is those floats rounded once. The gap is at
most 0.03 and crosses no bar. The canonical numbers are the left column, because every number in this
project traces to a Swift token or to `contrast.md`; a live browser reading is a check on the pipeline,
not a second source. Reproduce the right column with the same module, from the repository root:

```
python3 -c "import sys; sys.path.insert(0,'scripts'); import ds_tokens as t; h=lambda x:tuple(int(x[i:i+2],16)/255 for i in (1,3,5)); print('%.2f %.2f %.2f' % (t.contrast(h('#1f1e38'),h('#b98cea')), t.contrast(h('#ffffff'),h('#5849b2')), t.contrast(h('#ffffff'),h('#1f1e38'))))"
```

The ring half is **not** implemented in the guide. The guide draws one ring for everything:
`:focus-visible` sets `box-shadow: var(--focus-ring)`, and `--focus-ring` composes
`var(--size-focus-ring)` with `var(--color-focus)`, which is `ink` at 60 %. There is no block-scoped
override. Counted on 2026-09-24, `grep -c -- '--color-focus' design-system.html` returns 2, the
generated declaration and that one composition, and `grep -c ':focus-visible' design-system.html`
returns 2, the global rule and the phone's. So tabbing to the `.btn--onblock` in the on-block demo
draws a 60 % ink ring on `lavender`, which is **2.92** against the block, under the 3:1 non-text bar
part 2 of this Decision exists to hold. The page states in prose the rule its own CSS does not
implement. That is the class of defect ADR-024 fixed for Reduce Motion, and the same argument applies:
a guide that demonstrates the opposite of the rule printed beside it teaches the rule wrong. The fix
belongs in `design-system.html`, which this document does not own: scope a ring color to the block
demos, the way `DSBlock.focusRing` does in Swift.

**Applies to** `DSBlock.ctaFill`, `DSBlock.ctaLabel`, `DSBlock.focusRing`, `DSColor.focus`,
`DSSize.focusRing`, ADR-004, ADR-005, ADR-016, ADR-021, P-06, P-09, P-19.

## ADR-024 · The guide's reduce-motion cut excludes the deck, so the substitutions run

**Context.** `design-system.html` carried the usual blanket
`@media (prefers-reduced-motion: reduce)` rule: every element, `::before` and `::after` forced to
`animation-duration: .01ms !important` and `transition-duration: .01ms !important`. The swipe deck in
08 Swipe Deck is the one demo whose whole point is that this system **substitutes** two animations
rather than deleting them (P-15, `DSMotion.gated(_:reduce:reduced:)`). An uncommitted drag returns on
`DSMotion.snapBackReduced`, linear at `dur1` = 0.12 s, instead of the spring; a commit holds the
stamp for `DSMotion.stampHoldReduced` = 0.25 s and then leaves on `DSMotion.crossFade`, linear at
`fade` = 0.18 s. The deck's script reads the media query itself and sets exactly those, so the
blanket `!important` overrode both and cut them to nothing. The page demonstrated the opposite of the
rule printed beside it.

**Options.** (a) Leave it; the prose states the substitution even if the demo cannot show it.
(b) Exclude the deck from the blanket rule. (c) Let the deck's own declarations win with
`revert-layer`.

**Decision.** (b). The blanket rule's selector is now
`*:not(:where(.deck__card, .deck__card *))`, with the same two pseudo-element variants. `:where()`
contributes zero specificity, so the rule carries exactly the weight it always did and nothing else
on the page changes: buttons, stamps outside the deck, the spinner and scrolling all still take the
cut. Verified in a browser under emulated `prefers-reduced-motion: reduce`: a snap-back measures
0.12 s linear, a commit holds the stamp and then cross-fades, and a chrome button measures 1e-05s,
which is the `.01ms` cut.

Option (a) was rejected because a style guide that contradicts its own rule teaches the rule wrong.
Option (c) was rejected on a fact worth recording, because it looks like the idiomatic answer and is
not: **`revert-layer` cannot express this.** With no cascade layers declared, `revert-layer` rolls a
declaration back to the UA origin, whose `transition-duration` is `0s`. That is the same instant cut,
reached by a longer route.

**Consequences.** Reduce Motion is now honored in the guide the way `DSMotion` honors it in the app:
removal where the rule is a removal, substitution where the Reduce Motion table in `UI_DESIGN.md` §6
prescribes a substitute. The exclusion is scoped to `.deck__card` and its descendants, so a future
demo that needs a substitution has to be added to the selector deliberately, which is the point.

This is a new entry rather than an extension of ADR-021 because ADR-021 decided the focus ring and
its heading is a link target; motion has nothing to do with it. It is also not folded into ADR-020,
which fixes the guide's format and its section list, not its behaviour.

**Applies to** `design-system.html` (the `prefers-reduced-motion` block and the deck script),
`DSMotion.snapBackReduced`, `DSMotion.crossFade`, `DSMotion.stampHoldReduced`,
`DSMotion.gated(_:reduce:reduced:)`, ADR-019, ADR-020, P-15.

---

## ADR-025 · Information architecture: a derived queue, four screens, four assumptions

**Context.** The design system documents four screens and their strings, but nothing said what the
app is made of: which objects exist, which of their properties are the app's to write, how the
screens nest, what happens at launch and on every return to the foreground, what persists, and how
the app reacts to edits made in the Photos app. `docs/knowledge/IA.md` and `ia.html` now say all of
that. Writing it forced four structural choices that no earlier entry settles, and one modelling
choice that every screen depends on.

**Options.** For the queue: (a) store a per-screenshot "reviewed" flag; (b) derive membership from
the three destinations. For a heart set in Photos before the app existed: (a) count it as reviewed;
(b) keep an app-side "seen" set so only app-set hearts are verdicts. For the archive: (a) the album
is the truth, as `UI_DESIGN.md` §11.4 is written; (b) an app-local list is the truth and the album
mirrors it. For the limited-access interstitial: every launch, or only when the selection changed.
For the Credits screen: the Library footer, a header overflow menu on Review, or the Settings
bundle.

**Decision.** Queue (b): `unreviewed = not trashed, not archived, not favorited`, so the app owns no
flag that could drift from what Photos shows, and every screen, route and side effect in `IA.md`
follows from that one rule. The four remaining choices are taken as assumptions A1 to A4 in
`IA.md` §10, pending the owner's confirmation:

- **A1** a pre-existing heart counts as reviewed — the screenshot is a Favorite and never enters
  the queue;
- **A2** the limited interstitial shows on first grant and whenever the selected count differs
  from the one last acknowledged, otherwise limited access goes straight to Review;
- **A3** Credits is reached from the Library footer once access is granted;
- **A4** the archive list is the truth and the album mirrors it: a deleted album is recreated, a
  hand-removed member is un-archived, and an empty store adopts an existing album.

**Consequences.** The app persists two lists (trash, archive), two scalars (the album identifier,
the acknowledged selection count) and nothing else; the rewind entry lives in memory. Trash cannot
survive a reinstall and does not need to: nothing was deleted from Photos, so the screenshots return
to the queue. When A4 is confirmed, `UI_DESIGN.md` §11.4's "Archive lists members of the album"
becomes "Archive lists the archive list; the album mirrors it", and ADR-010's fallback under
limited access stops being a fallback — it is the normal path with the album write skipped. Until
the owner confirms, this entry's status is **Proposed** and the diagrams are drawn as if all four
assumptions hold. One question is recorded as open rather than assumed: whether the Review card
offers pinch-to-zoom.

**Confirmed, 2026-09-27.** The owner confirmed A1 to A4 as written ("가정 네 개 다 그대로 가자").
Status is **Active**. The conditional consequence is now in force: `UI_DESIGN.md` §11.4 reads
"Archive lists the app's archive list; the album mirrors it", `IA.md` §10 is retitled to record
the decisions rather than propose them, and ADR-010 carries a dated Correction making the list
the normal path. The pinch-to-zoom question stays open.

**Applies to** `docs/knowledge/IA.md`, `ia.html`, ADR-008, ADR-010, ADR-011, ADR-014, ADR-015,
`UI_DESIGN.md` §11.

---

## Superseded

### S-1 · Dark-first adaptive tokens (2026-09-22) — superseded by ADR-006
Chosen when the card was expected to sit on a dark canvas for separation. Replaced after the
owner saw the three mock-ups and chose light-only with a white background.

### S-2 · SF Pro Rounded (2026-09-22) — superseded by ADR-003
Chosen for a licence-free playful face. Replaced by Acme Gothic + Pretendard at the owner's request;
the display half became Forager Bold Overlap on 2026-09-24 (ADR-003's correction).

### S-3 · SF Symbols (2026-09-22) — superseded by ADR-017
Kept only as the development fallback inside `DSIconRef`.

### S-4 · 4-pt spacing scale, rounded-rectangle stamps (2026-09-22) — superseded by ADR-018 / ADR-013
Replaced by the reference spacing scale and pill stamps.
