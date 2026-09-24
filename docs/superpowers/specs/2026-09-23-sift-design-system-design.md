# Design System — Design Spec

2026-09-23 · iOS 17 SwiftUI · light-only · design-system phase, not the app phase

## 1. Context

### Why a design system first

The product is a screenshot triage app: it shows one screenshot at a time as a card, newest
unreviewed first, and the user swipes left to trash it, right to archive it, up to favorite it. The
whole product is one gesture repeated a few hundred times, which means the parts that decide whether
it feels good are the parts a design system owns — the commit threshold, the stamp reveal curve, the
haptic weight per direction, the exit duration, the contrast of a stamp on an arbitrary screenshot.
Those are values, not screens. Building the screens first would mean tuning those values inside view
code and then extracting them afterwards, which is how the previous project ended up with a document
and a Swift file that disagreed.

So this phase produces the tokens, the rules, the documentation and a living HTML guide, plus the
product spec that justifies them. The app body is the next phase.

### Course context

IXD 750 Product Innovation. The deliverable is submitted for the course, so the documentation is in
English (ADR-020) and the HTML guide follows the format of the owner's previous design-system guide:
sticky sidebar navigation, colored hero, numbered sections, a single 1200 px breakpoint.

### Owner decisions

Every value in this spec traces to a decision the owner confirmed on one of three days.

| Date | Decision |
|---|---|
| 2026-09-22 | iOS native SwiftUI, iOS 17+, XcodeGen conventions for the app phase |
| 2026-09-22 | Documentation in English; deliverables are Markdown knowledge docs, Swift token files, and one HTML style guide |
| 2026-09-22 | Three swipe directions: left = the app's own Trash, right = an app-created Photos album, up = the Photos favorite flag |
| 2026-09-22 | Trash holds items until a manual permanent delete; individual and bulk permanent delete, plus restore |
| 2026-09-22 | Undo is a one-step rewind of the last swipe |
| 2026-09-22 | No AI in this product |
| 2026-09-22 | Four screens in v1: Permission, Review, Trash, Library |
| 2026-09-22 | One queue, newest first, with a visible progress position |
| 2026-09-22 | Lazyweb is used for reference search only; no generated report |
| 2026-09-22 | Mood: bold and playful, saturated verdict colors, large stamps, game-like feedback, but the screenshot stays the subject |
| 2026-09-23 | Light only, on a plain white background, after reviewing three mock-ups (light color-block, dark-first, light-only) |
| 2026-09-23 | Icons: Noun Project, bold solid, CC BY with a credits screen |
| 2026-09-23 | Spacing, radius, elevation and grid inherited verbatim from the owner's previous system |
| 2026-09-23 | Stamps are pills reading TRASH / ARCHIVE / FAVE |
| 2026-09-24 | Type: Forager Bold Overlap for display, Pretendard for text |

### Decision history

The first plan, written 2026-09-22, was dark-first with adaptive light/dark token pairs, used SF Pro
Rounded as the system face, used SF Symbols as the icon set, and specified a 4-pt spacing scale with
rounded-rectangle stamps. All four were revised on 2026-09-23 and are recorded as superseded
decisions rather than deleted: S-1 (dark-first adaptive tokens) superseded by ADR-006, S-2 (SF Pro
Rounded) by ADR-003, S-3 (SF Symbols) by ADR-017, S-4 (4-pt scale and rounded-rectangle stamps) by
ADR-018 and ADR-013. SF Symbols survive in exactly one role, as the development fallback inside
`DSIconRef`. Where the earlier plan and `DECISIONS.md` disagree, `DECISIONS.md` is correct.

The display face changed on 2026-09-24. **Forager Bold Overlap** replaced Acme Gothic, and three
things follow from it. Forager Overlap has no cut heavier than Bold, so `DSFont.displayBold` and
`DSFont.displayBlack` both resolve to `Forager-BoldOverlap`: the two display slots are the same face,
and the web guide sets every display role at weight 700 rather than 900. Forager Overlap's strokes
intentionally run into each other, so `DSTextRole.tracking` opens the display roles OUT by 0.03 em
(34 × 0.03, 28 × 0.03 and 24 × 0.03 pt for `display`, `headline` and `title`) instead of tightening
them; the Pretendard roles keep their own tracking. And `DSFace` was rebuilt: a face is no longer two
lines of eyes over a mouth but one glyph borrowed from a world script framed by round parentheses,
seven cases for the seven `DSBlock` values, no glyph used twice. The five old cases (hello,
delighted, relieved, waiting, sorry) are gone, and so is the mapping that had to spend `waiting` and
`sorry` on two blocks each. Forager is also Mark Simonson Studio, also Adobe Fonts, also web and
desktop only, so the Pretendard Bold runtime fallback and its reasoning are unchanged. ADR-003 and
ADR-016 keep their numbers.

A code review on 2026-09-24 corrected the token and script layer, and this spec was updated to match.
Two live ADRs kept their numbers and gained dated **Correction** paragraphs: ADR-004 (bold weight
does not make 16 pt text WCAG large text, so the destructive button label is now navy `ink` on
tomato) and ADR-002 (the rename scope is larger than the lint's reach). Two ADRs were added, ADR-021
(focus ring at 60 %) and ADR-022 (the token script fails loudly). Nothing was superseded.

Three further corrections landed later on 2026-09-24, after the guide existed and could be measured.
Two of them are numbered entries of their own, ADR-023 (the CTA pill and the focus ring on a color
block) and ADR-024 (the guide's reduce-motion cut excludes the deck); the third, the display-font
probe, is a dated **Correction** on ADR-003 and a risk note in section 8 rather than a new number.
The log therefore runs ADR-001 to ADR-024, with the command that re-derives that range in section 6.

**The CTA pill and the focus ring on a block became `DSBlock` properties.** They had been free
choices; they are now derived. `DSBlock.ctaFill` is the block's own ink, and `DSBlock.ctaLabel` is
that ink's counterpart: `DSColor.onAccent` on the six blocks whose ink is `ink`, `DSColor.accent` on
`denied`, the one block whose ink is `onAccent`. `DSBlock.focusRing` is the block's ink at full
strength rather than `DSColor.focus`. Both were measured with `scripts/ds_tokens.py`. A white pill
is invisible as a shape against its own block: 1.15 on `lime`, 1.15 on `fave.soft`, 1.53 on `pink`,
1.79 on `mint`, 2.61 on `lavender`; a navy pill on `violet` is 2.33. Filled with the block's ink the
pill clears 4.61 at worst (tomato) and 14.01 at best (pale yellow) on all seven blocks, and the
label clears 16.16. `DSColor.focus` is ink at 60 %, tuned for the neutral surfaces, and composited
over a saturated block it falls to 2.65 on tomato, 2.92 on lavender and 1.71 on violet, all under
the 3:1 non-text bar. The pill fill and the ring add no rows to the contrast table, because each is
the same pair as `ink` on that block, which the block copy rows already enforce at the stricter 4.5
text bar; two rows were added for the pill *label*, which is what took the table from 41 pairs to
43.

Two consequences follow, and both are part of the same rule. First, a block carries **one** filled
action. A second action on it is bare text in the block's ink, because a filled secondary would be a
shape and a shape owes 3:1 against what it sits on, which on blocks means a row per fill;
`surfaceRaised` measures 2.16 against `lavender` and clears the bar on `violet` alone. With no fill
there is no shape to measure, only the label, which the block's own copy row already clears. Second,
`View.dsFocusRing` now takes the ring color as a parameter, `DSColor.focus` by default, precisely
because the ring is translucent and its ratio depends on what it sits on; a control on a block passes
`DSBlock.focusRing`. Any statement that the helper hard-codes `DSColor.focus` describes the older
signature.

**The guide's Reduce Motion block stopped killing its own substitutions.** Its blanket
`prefers-reduced-motion` rule cuts every duration to `.01ms !important`, which had been overwriting
the two substitutions the guide demonstrates. Its selector is now `*:not(:where(.deck__card,
.deck__card *))`, with the same two pseudo-element variants, so the deck is excluded rather than
selected; `:where()` contributes zero specificity, so the rule keeps the weight it always had and
everything outside the deck still takes the cut (ADR-024). Verified in a browser with the query
emulated: the snap-back measures 0.12 s linear (the `DSMotion.snapBackReduced` substitute) and a
commit holds the stamp and then cross-fades, while a chrome button measures 1e-05 s. `revert-layer`
does not work for this: with no cascade layers declared it rolls back to the UA value, 0 s, the same
instant cut.

**A runtime trap was removed from `DSTypography.swift`.** `DSFont.displayAvailability`, a dictionary
literal keyed by PostScript name, had acquired two identical keys once both display constants
resolved to `Forager-BoldOverlap`; a Swift dictionary literal with duplicate keys traps at
construction, so the app would have crashed on the first display role it rendered. It is now
`DSFont.availableDisplayNames`, a `Set<String>` built in a closure that probes each name on its own.
The §8 risk note carries the detail.

This section used to end with two lists of corrections still owed: three passages carrying the
superseded block-CTA wording, and five naming `DSFont.displayAvailability`. Both were snapshots of a
moment, and both have been overtaken. Re-checked on 2026-09-24 with

```
grep -c 'navy pill or a white pill' docs/knowledge/DECISIONS.md
grep -rn displayAvailability Sift/
```

which printed `2` and no output respectively.

**The block-CTA wording is corrected everywhere it was owed.** The fixes are identified here by what
they say, not by where they sit, so this paragraph does not go stale the next time those files are
edited.

- `UI_DESIGN.md` §9 lists `DSBlock.ctaFill`, `DSBlock.ctaLabel` and `DSBlock.focusRing` as the rule,
  and carries a dated **Correction** that quotes the retired sentence and gives the measurements
  that retired it.
- The fourth row of its §10 Buttons table is `block CTA`, filled with `DSBlock.ctaFill` and labelled
  with `DSBlock.ctaLabel`. The prose under the table states what the old `white pill` row claimed and
  what a white pill actually measures.
- ADR-005 gained a dated **Correction** headed with the retired sentence in quotation marks. Its
  Decision paragraph still contains that sentence, and that is the log's own rule rather than an
  outstanding fix, because `DECISIONS.md` never rewrites a decided body. The two hits the first
  command counts are exactly those: the original Decision, and the Correction that quotes it in order
  to withdraw it.
- The guide renders the rule in both directions. `.btn--onblock` is `--color-ink` with an
  `--color-on-accent` label, `.btn--onblock-inverted` is the reverse for the one block whose ink is
  white, and the demo caption states that the pill is never a free choice between navy and white.
- `DSColor.swift`'s `accent` comment says the CTA on a block is NOT a free choice between that navy
  pill and a white one, and names `DSBlock.ctaFill` as what it is instead.

**`DSFont.displayAvailability` is gone from the code and historical in the prose.** The second
command returns nothing: the symbol does not exist, and `DSTypography.swift` declares
`DSFont.availableDisplayNames`, a `Set<String>` built in a closure that probes each name on its own.
The old count of five places is dropped rather than re-stated, because a count of mentions is exactly
the kind of claim that decays. What matters is that every surviving mention is deliberately
historical and says so in its own sentence: `UI_DESIGN.md` §2's dated Correction and the closed half
of its open question 8 both describe the trap in the past tense, its changelog records the rename,
ADR-003's body keeps the wording the log preserves, and ADR-003's Correction is headed
"`displayAvailability` was a runtime trap, not a lookup". That heading also settles the other claim
this section used to make. ADR-003's correction is no longer wrong on the substance: it states that a
dictionary literal with duplicate keys traps at construction, that the property is lazy so the trap
would have fired on the first display role rendered, and that the "one duplicate lookup" wording
described a cost that was never paid.

## 2. Goals and non-goals

### Goals

1. One canonical place for every value. Swift token files are it; the CSS variables, the contrast
   table and the name lint are all generated from them (ADR-001).
2. A measured accessibility floor. The contrast table is generated from the same numbers the app
   compiles, so it cannot describe a palette that is not shipping.
3. Interaction physics written down as numbers with reasons — the commit threshold, the sector
   model, the exit duration formula, the stamp reveal window — so the app phase implements a
   specification rather than re-inventing feel.
4. A submittable artifact: an English Markdown design system plus a single-file HTML guide that
   demonstrates the swipe rather than describing it.
5. A brand-free token layer. The product name is provisional, so in Swift it is typed once, in
   `Brand.swift`, and no `DS` type, CSS variable or asset name carries it. A rename is that one
   constant plus the prose that names the product — the guide, the document titles, and the copy
   quoted in `DECISIONS.md`; the lint covers `Sift/DesignSystem/*.swift` only, and ADR-002 records
   the count per file, recounted whenever those documents change.

### Non-goals

1. Not a component library. No SwiftUI views ship in this phase; components are specified in
   `UI_DESIGN.md` and built in the app phase.
2. Not a theming system. One color scheme, no adaptive pairs, no user-selectable theme.
3. Not a design-tool library. No Figma file, no Style Dictionary, no JSON token export.
4. Not a full accessibility audit. The contrast bar is automated; VoiceOver and Dynamic Type are
   specified here and verified on a device in the app phase.

## 3. Token architecture

Swift is canonical. `scripts/ds_tokens.py` parses the token files and derives everything else, so
the mirrors cannot drift. Details and every value live in `docs/knowledge/UI_DESIGN.md`; this is the
shape.

| Group | Type | Lives in | Notes |
|---|---|---|---|
| Color | `DSColor`, `VerdictColorSet` | `DSColor.swift` | 30 tokens, each one fixed `oklch(L, C, H[, a])`. Surfaces, ink ramp, accent, three verdict sets, five expressive colors, overlays. The ink ramp's tightest measured rows are `ink2` at 6.19 and `inkMuted` at 4.77, both on `surfaceRaised`, and the doc comments carry those figures rather than rounded ones. See UI_DESIGN §1 |
| Type | `DSFont`, `DSTextRole` | `DSTypography.swift` | 11 roles. Ten bind to a Dynamic Type style through `relativeTo:`; `stamp` binds to none, is scaled at the call site, and is clamped to 44 pt by `stampFont(size:)`, which returns a fixed-size font. Two faces: Forager Bold Overlap for display at its one weight, Pretendard for text in four weights. Display roles are tracked OUT by 0.03 em, not tightened: 34 × 0.03, 28 × 0.03 and 24 × 0.03 pt for `display`, `headline` and `title`, and `stamp` at a flat +2 pt. Display is not licensed for the app yet, and `DSFont.availableDisplayNames` is a `Set` that probes each PostScript name on its own. See UI_DESIGN §2 |
| Spacing, radius, grid | `DSSpace`, `DSRadius`, `DSGrid` | `DSLayout.swift` | Inherited verbatim from the previous system (ADR-018). See UI_DESIGN §3 |
| Sizes | `DSSize` | `DSLayout.swift` | 16 fixed sizes, from the 44 pt tap floor to the card stack's offset and scale step. `toastVisibleSeconds` was deleted as a duplicate of `DSMotion.toastVisible`. See UI_DESIGN §4 |
| Swipe physics | `DSSwipe` | `DSLayout.swift` | 14 tokens: commit distance and velocity, rotation, stamp reveal window, sector hysteresis, exit geometry, promotion point. See UI_DESIGN §6 |
| Elevation, layering | `DSShadow`, `DSLayer` | `DSElevation.swift` | Two shadow levels, both two soft layers; a five-rung z ladder. No borders. `View.dsFocusRing(_:cornerRadius:color:)` takes the ring color, defaulting to `DSColor.focus`, because the ring is translucent and its ratio depends on what it sits on; a control on a block passes `DSBlock.focusRing`. See UI_DESIGN §5 |
| Motion | `DSMotion`, `DSPressStyle` | `DSMotion.swift` | 9 durations, 4 curves, 5 springs, 2 named Reduce Motion substitutes (`snapBackReduced`, `crossFade`), the exit-duration formula, and two `gated` overloads: remove a transition, or replace it with a named token. See UI_DESIGN §6 |
| Haptics | `DSHaptic` | `DSHaptics.swift` | 12 events; impact weight encodes swipe direction; one double pulse. See UI_DESIGN §7 |
| Icons | `DSIconRef`, `DSIcon`, `DSIconCredits` | `DSIcon.swift` | 12 glyphs, each with an asset name, a development fallback symbol, and a Noun Project query. See UI_DESIGN §8 |
| Illustration | `DSFace`, `DSBlock` | `DSIllustration.swift` | 7 typographic faces and 7 screen-to-block mappings, one face per block, no glyph used twice. A face is round parentheses plus one world-script glyph, and every face is `accessibilityHidden`. Two blocks borrow a verdict color: onboarding `trash.main`, limited `fave.soft`. The borrowing runs one way only, which is what the `DSBlock` header comment now says: the expressive palette never carries verdict meaning, two blocks deliberately borrow a verdict color, and there is no third. `DSBlock` also derives what sits on the block: `ctaFill` is the block's ink, `ctaLabel` is that ink's counterpart, `focusRing` is the ink at full strength. A block carries one filled action, so a second action on it is bare text in the block's ink. No image assets. See UI_DESIGN §9 |
| Brand | `Brand` | `Brand.swift` | The only place the product name is typed |

The parser depends on three literal shapes in the Swift source — `oklch(L, C, H[, a])`,
`<token>.opacity(a)`, and `static let name: CGFloat = value` — so a refactor that changes how a
token is written breaks generation. Since ADR-022 that break is loud: `parse_colors` compares the
declarations it found against the tokens it produced and `parse_numbers` exits on any numeric
declaration it cannot read, so the run aborts instead of silently emitting a shorter table.

The script's module docstring now describes what `lint` actually does, which matters because "unused
variable" is easy to misread. Usage is counted by exact name outside comments: HTML comments are
stripped first, each name is matched with a trailing-character guard, and two occurrences are
required, the declaration in the generated `:root` block plus at least one real use. Entries in
`DECLARATION_ONLY` print as `EXCEPTION` lines carrying their recorded reason rather than being
tolerated in silence, and the empty icon-credits array prints as a `WARNING` that does not change the
exit code.

## 4. Components

Fourteen components, specified in `UI_DESIGN.md` §10 with anatomy, tokens, states and an
accessibility contract each — one `###` entry per row of the table below.

| Component | Screens | State count |
|---|---|---|
| `ScreenshotCard` | Review | 7 |
| `CardStack` | Review | 4 |
| `VerdictStamp` (×3) | Review | 3 |
| `VerdictButtonRow` + `RewindButton` | Review | 3 |
| `ProgressCounter` | Review | 3 |
| `ThumbnailCell` | Trash, Library | 3, two variants |
| `AssetViewer` | Trash, Library | 4, two action sets |
| `PurgeAllSheet` | Trash | 3 |
| `SegmentedControl` | Library | 2 |
| `EmptyState` | Review, Trash, Library | 5 variants |
| `PermissionScreen` + `SwipeLegend` + `DemoStack` | Permission | 4 |
| Buttons: primary, secondary, destructive, block CTA | Permission, Trash, Library | 4 each |
| `Toast` | all | 3 |
| Credits screen | pushed from Permission | 2 |

Two rules shape the set. First, a verdict has one code path: the verdict buttons synthesize a flick
and run the same exit pipeline as a swipe, so button and gesture cannot diverge. Second, every
component declares its states as an enum and every case is designed — loading, empty and error
included.

## 5. Screens

Four screens, no tab bar (ADR-011). Review is the root; Trash and Library are pushed from icon
buttons in the Review header. Full region and copy tables are in `UI_DESIGN.md` §11.

**Permission.** Two steps: the app explains itself, then the system dialog. Authorization is
requested on tap, never on launch. Three outcomes — full access goes to Review; limited access gets
an interstitial with the count the user picked and a way to pick more; denied gets an Open Settings
path and re-checks whenever the scene becomes active (ADR-010). The top 55 % is a demo stack running
the real gesture code with synthetic input, so the demo cannot drift from the product.

**Review.** Progress counter leading, Trash (with a count badge) and Library trailing, the card
stack in the middle, the verdict button row docked at the bottom. One queue, newest unreviewed
first; restored items re-enter in date order; screenshots taken during a session join silently
through a change observer. States: loading, reviewing, exiting, rewinding, all done, no screenshots,
permission lost.

**Trash.** A three-column grid, most recently trashed first, no multi-select (ADR-015). Restore and
permanent delete from a viewer or a context menu. Permanent deletion of one item has no in-app
confirmation because PhotoKit's own dialog is the confirmation; "delete all" gets one in-app sheet
first, `PurgeAllSheet`. Its title states the count, `"Delete 27 screenshots permanently?"`. Its body
says where the files go and pre-announces the second dialog in the same breath: `"They leave
\(Brand.name) for good and go to Photos' Recently Deleted for 30 days. iOS will double-check —
that's expected."` Its buttons are `"Delete 27 permanently"` and `"Keep them"`. The count and the
size together belong to the docked destructive button, `"Delete all permanently (27 · 48 MB)"`, not
to the sheet. Those are the strings in UI_DESIGN §11.3, and the guide renders the same ones with the
brand name interpolated: the sheet in its destructive-ladder demo, the docked button in its button
row and in its Trash screen mock.

**Library.** Favorites and Archive segments over the same grid. An asset can be in both. The viewer
offers a move to the other segment, and a trash action with no confirmation.

The destructive-action ladder that governs all of this has three rungs, and its axis is
recoverability after the user confirms, not how alarming the wording is: rung 0 is reversible and
silent, rung 1 is irreversible with the iOS dialog as the single confirmation, rung 2 is
irreversible with an in-app sheet before the iOS dialog (ADR-009).

## 6. Deliverables and tree

```
Sift/
├── .gitignore
├── README.md
├── design-system.html                  single-file living style guide
├── docs/
│   ├── references.md                   reference boards, format reference, 3 Lazyweb links
│   ├── knowledge/
│   │   ├── DECISIONS.md                ADR-001 to ADR-024 plus S-1 to S-4
│   │   ├── DESIGN_PRINCIPLES.md        P-01 to P-23
│   │   ├── PRINCIPLES_CHECKLIST.md     27 lines for 23 principles, plus a pre-ship list
│   │   └── UI_DESIGN.md                the design system
│   └── superpowers/specs/
│       └── 2026-09-23-sift-design-system-design.md   this file
├── scripts/
│   ├── ds_tokens.py                    contrast | emit-css | lint, standard library only
│   ├── typecheck-ds.sh                 swiftc -typecheck against the iOS 17 simulator SDK
│   └── out/                            generated, git-ignored
│       ├── contrast.md
│       └── tokens.css
└── Sift/DesignSystem/
    ├── Brand.swift
    ├── DSColor.swift
    ├── DSTypography.swift
    ├── DSLayout.swift
    ├── DSElevation.swift
    ├── DSMotion.swift
    ├── DSHaptics.swift
    ├── DSIcon.swift
    └── DSIllustration.swift
```

The ADR range in that tree is derived, not remembered. Re-derive it, and check that the tree still
matches the disk, with:

```
grep -c '^## ADR-' docs/knowledge/DECISIONS.md
grep -o '^## ADR-[0-9]\{3\}' docs/knowledge/DECISIONS.md | tail -1
grep -c '^### S-' docs/knowledge/DECISIONS.md
for p in .gitignore README.md design-system.html docs/references.md \
  docs/knowledge/{DECISIONS,DESIGN_PRINCIPLES,PRINCIPLES_CHECKLIST,UI_DESIGN}.md \
  docs/superpowers/specs/2026-09-23-sift-design-system-design.md \
  scripts/ds_tokens.py scripts/typecheck-ds.sh scripts/out/{contrast.md,tokens.css} \
  Sift/DesignSystem/*.swift; do [ -e "$p" ] || echo "MISSING $p"; done
```

On 2026-09-24 those printed `24`, `## ADR-024`, `4`, and nothing: the log runs ADR-001 to ADR-024
with no gaps, four superseded entries sit alongside it, and every path drawn in the tree exists. The
last command is silent on success, so any line it prints is a path this section promises and the
repository does not have.

`scripts/out/` is git-ignored: it is scratch. The copies that matter are pasted into the documents
— the contrast table into `UI_DESIGN.md` §1, the `:root` block into `design-system.html` — and the
lint verifies that the pasted copies are current. No Xcode project is generated in this phase; the
token files are type-checked without one.

## 7. Verification

Four commands, not three — `typecheck-ds.sh` is part of the set.

```
python3 "scripts/ds_tokens.py" contrast     # 43 pairs · 0 failure(s), no gamut warning
python3 "scripts/ds_tokens.py" emit-css > scripts/out/tokens.css
python3 "scripts/ds_tokens.py" lint         # last line "lint: OK"
scripts/typecheck-ds.sh                     # prints "typecheck: OK"
```

Of the 43 contrast pairs, 40 are enforced and 3 are informational: the yellow edge against `canvas`,
the same edge against a white screenshot, and the raised fill against `canvas`. `lint` prints three
`lint: EXCEPTION` lines for the variables the guide declares but cannot consume, and one
`lint: WARNING` line while `DSIconCredits.entries` is empty; both are expected output and the verdict
is the last line (ADR-022). The EXCEPTION lines are the `DECLARATION_ONLY` entries printing their own
recorded reason, the WARNING does not change the exit code, and the usage those checks count is
counted by exact variable name outside HTML comments. The module docstring in `scripts/ds_tokens.py`
states all three.

`typecheck-ds.sh` pins `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer` because
`xcode-select -p` on this machine points at CommandLineTools, which has no iOS SDK.

Browser check of `design-system.html`, either by opening the file or by serving it with
`python3 -m http.server`:

1. Every swatch renders and the contrast figures next to it match the generated table, and no
   swatch breaks P-19 on its own page: an `on` color sits on a `main` fill only at the 32 pt stamp
   size, so the verdict swatch's big word is the licensed case and the small `on` sample sits on the
   `soft` tint with an `ink` label beside it.
2. In the swipe demo, a drag past 120 pt commits and a shorter drag snaps back.
3. The stamp starts appearing at 20 pt of travel and is fully opaque exactly at the commit
   distance.
4. Rewind returns the last card and fades its stamp out.
5. The progress counter updates and its digits do not shift horizontally.
6. A stamp is legible over the all-white placeholder screenshot — the case that rules out outlined
   stamps.
7. The page is checked at both sides of the 1200 px breakpoint, and with `prefers-reduced-motion`
   set. Under the emulated query the deck substitutes rather than freezes: the snap-back measures
   0.12 s linear and a commit holds the stamp and then cross-fades, while a chrome button measures
   1e-05 s, the blanket cut.
8. The on-block buttons render the ADR-023 rule in both directions and only one of them is filled.
   `.btn--onblock` is a navy pill with a white label on the lavender demo block,
   `.btn--onblock-inverted` is a white pill with a navy label on the violet one, and the second
   action beside the first is `.btn--onblock-text`, bare text with no fill. Measured live in a
   browser, the two pills agree with the generated table to within 0.03: the navy pill against
   lavender is the `ink` on `lavender` row at 6.18, the white pill against violet is the `onAccent`
   on `violet` row at 6.95, and each label reads the 16.16 of the two CTA-label rows. The figures in
   the documents stay the generated ones, since those are the numbers the app compiles.

## 8. Risks

**Limited photo access.** The screenshots smart album may return only the user's selected assets,
and PhotoKit may refuse album creation or modification entirely under limited access. If it does,
Archive falls back to an app-local list and Library must be able to render either source. To verify
on a device in the app phase (ADR-010).

**The `deleteAssets` dialog.** It cannot be styled and cannot be suppressed, and the user can
cancel it. Cancellation leaves Trash untouched and posts a "Not deleted" toast. Copy must not
promise that anything is gone: permanently deleted assets sit in Photos' Recently Deleted for 30
days, and the purge sheet says so in its body string, quoted in section 5.

**OneDrive and git.** The repository lives inside a OneDrive folder, and sync can corrupt `.git`.
Mitigation: mark the folder "always keep on this device"; the fallback is
`git init --separate-git-dir`. The parent folder name also begins with a space, so every path in
every script and command must be quoted. `ds_tokens.py` resolves its paths relative to its own
file, which makes the leading space harmless there.

**Color-vision deficiency.** Tomato and golden yellow fall on the same side of a deuteranope's
axis; cobalt stays apart from both. Hue distance alone is therefore not sufficient, which is why
direction, glyph and word are the primary channels and hue is the third (ADR-004). A simulation pass
on the three verdict colors is still outstanding.

**Forager Overlap license.** Adobe Fonts covers web and desktop use, not embedding in a mobile app.
Until an app license is bought from Mark Simonson Studio the app does not bundle the face, and
`DSFont.resolvedDisplay(_:)` returns Pretendard Bold instead. Both display slots name the same
PostScript face, `Forager-BoldOverlap`, so the fallback is all-or-nothing rather than per cut: if the
file is missing, `display`, `headline`, `title` and `stamp` all render Pretendard Bold. The
PostScript name is unverified until the file exists; a wrong name fails silently into the fallback.
The HTML guide loads Typekit kit `blt4ith` (supplied 2026-09-24, family `forager-overlap`), which
carries 400 and 700 and no heavier cut, so every display role renders at 700 on the web rather than
the 900 the previous face allowed. Typekit serves the kit with `max-age=600`, so the guide's
stylesheet link carries a `?v=` cache-buster; bump it on every kit edit or the change stays invisible
for ten minutes.

**Display fallback granularity.** Resolved 2026-09-24, and worth recording because the failure was a
crash rather than a cosmetic drift. `DSFont.displayAvailability` was a dictionary literal keyed by
PostScript name, and once `displayBold` and `displayBlack` both resolved to `Forager-BoldOverlap`
its two keys were the same string. A Swift dictionary literal with duplicate keys traps at
construction, so the app would have crashed on the first display role it rendered, not merely paid
for an extra lookup. It is now `DSFont.availableDisplayNames`, a `Set<String>` built in a closure
that probes each name on its own: the duplicate collapses instead of trapping, and if the family is
ever split into two real cuts with only one of them shipped, the fallback still happens per cut
instead of drifting to the system font. The residual risk is the one in the paragraph above, not
this one: the PostScript names stay unverified until the font files exist, and a wrong name fails
silently into Pretendard Bold.

**Noun Project credits.** The icons are CC BY, so each shipped glyph needs an attribution line.
`DSIconCredits.entries` is currently empty and every `DSIconRef.image` returns its SF Symbol
fallback. Shipping an asset without adding its credit in the same commit is a license violation, so
the two changes belong together.

## 9. Out of scope

- The app body: `project.yml`, the PhotoKit service layer, review-history persistence, and the
  implementation of the four screens.
- `ARCHITECTURE.md`. There is no app architecture to describe yet.
- Dark mode, and any adaptive color pair.
- Sound. There is no settings screen in v1, so a sound that cannot be turned off would be a defect
  (ADR-012).
- A settings screen, and any statistics or history screen.
- Any AI feature.
- A Figma library or any design-tool export.
