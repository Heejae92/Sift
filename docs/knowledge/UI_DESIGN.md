# Sift — Design System

> Provisional name (ADR-002). It is typed once in `Brand.swift`, and the prose that names the
> product carries it too: the title line above, the ADR bodies that quote screen copy, and
> `design-system.html`, which holds it in its title, its wordmark and the screen strings it
> demonstrates. `ds_tokens.py lint` enforces the Swift half only, failing if the name appears in
> any file under `DesignSystem/` but `Brand.swift`.
>
> **Correction, 2026-09-24.** This note used to list `README.md` here, and so did the Prefix rule
> in [§0](#prefix-rule). Neither was right, and the per-file tally that replaced them was wrong in
> turn: it credited `design-system.html` with eight where the file spells the word ten times. The
> tally is removed rather than repaired. It pinned a number to each of four files that are edited on
> their own schedules, so it was stale the moment any one of them changed, and a number nobody can
> trust is worse than no number.
>
> The rule is what to carry. An occurrence is prose only if a rename would have to change it, so the
> directory name inside a path never counts, and neither does a path assembled in code, such as the
> `ROOT / "Sift" / "DesignSystem"` join in `ds_tokens.py`. That is the whole reason `README.md` does
> not belong in this list: it spells the word only inside `Sift/DesignSystem/`. Prose that does name
> the product lives in the title line above, in the ADR bodies that quote screen copy, and in
> `design-system.html`, which holds it in its title, its wordmark and its screen strings. To read the
> current state instead of a remembered one, run
> `grep -ro --include='*.swift' --include='*.html' --include='*.md' --include='*.py' 'Sift' .` and
> discount every hit the same command reports for `'Sift/'`, plus the one path join named above. The
> lint does not check any of this; it checks `DesignSystem/` only.

v1.4 · 2026-09-24 · light-only · iOS 17 SwiftUI

The product is a screenshot triage app. It shows one screenshot at a time as a card, newest
unreviewed first, with a progress counter. Swipe left sends it to the app's own Trash, right to a
Photos album, up to Photos favorites. One step of rewind. Four screens: Permission, Review, Trash,
Library. This document is the written half of the design system; the Swift files under
`Sift/DesignSystem/` are the executable half, and they win on every number.

## Contents

| § | Section |
|---|---|
| 0 | [Sources of truth](#0-sources-of-truth) |
| 1 | [Color](#1-color) |
| 2 | [Typography](#2-typography) |
| 3 | [Spacing, radius, grid](#3-spacing-radius-grid) |
| 4 | [Sizes](#4-sizes) |
| 5 | [Elevation and layering](#5-elevation-and-layering) |
| 6 | [Motion and swipe physics](#6-motion-and-swipe-physics) |
| 7 | [Haptics](#7-haptics) |
| 8 | [Icons](#8-icons) |
| 9 | [Illustration](#9-illustration) |
| 10 | [Components](#10-components) |
| 11 | [Screens](#11-screens) |
| 12 | [Copy and voice](#12-copy-and-voice) |
| 13 | [Accessibility](#13-accessibility) |
| 14 | [Token index](#14-token-index) |
| 15 | [Open questions](#15-open-questions) |

---

## 0. Sources of truth

Swift is canonical (ADR-001). A value is typed once, in one Swift file, and everything else is
derived from it by one script. The previous project kept Markdown canonical and mirrored it into
Swift by hand; the two drifted. Here the mirror is generated, so it cannot.

### What is canonical

`Sift/DesignSystem/*.swift`. Nine files, no other source of values.

| File | Owns |
|---|---|
| `Brand.swift` | `Brand.name`, `Brand.archiveAlbumTitle` — the only place the product name is typed |
| `DSColor.swift` | every color token, `VerdictColorSet`, the OKLCH → sRGB conversion |
| `DSTypography.swift` | `DSFont` PostScript names, `DSTextRole`, `.dsType(_:)` |
| `DSLayout.swift` | `DSSpace`, `DSRadius`, `DSGrid`, `DSSize`, `DSSwipe`, `DSOpacity` |
| `DSElevation.swift` | `DSShadow`, `.dsShadow(_:)`, `.dsFocusRing(_:cornerRadius:color:)`, `DSLayer` |
| `DSMotion.swift` | `DSMotion` durations, curves and springs, `DSPressStyle` |
| `DSHaptics.swift` | `DSHaptic`, `.dsHaptic(_:trigger:)` |
| `DSIcon.swift` | `DSIconRef`, `DSIcon` inventory, `DSIconCredit`, `DSIconCredits` |
| `DSIllustration.swift` | `DSFace`, `DSBlock` |

### What is generated

| Artifact | Produced by | Consumed by |
|---|---|---|
| `scripts/out/contrast.md` | `ds_tokens.py contrast` | pasted verbatim into [§1 Measured contrast](#measured-contrast) |
| `scripts/out/tokens.css` | `ds_tokens.py emit-css` | pasted verbatim into the `:root` block of `design-system.html`; indexed in [§14](#14-token-index) |
| the name lint | `ds_tokens.py lint` | fails the build when a token is missing from this file or from the guide |

The parser depends on literal shapes in the Swift source: `oklch(L, C, H)`, `oklch(L, C, H, a)`,
`<token>.opacity(a)`, and `static let name: CGFloat = value`. A declaration the parser cannot read
is a hard failure, not a silent skip: the script exits with the offending line rather than emitting
a short table that looks plausible. Changing a token means running all four commands, not just the
one that seems relevant.

### The four commands

```
python3 "scripts/ds_tokens.py" contrast
python3 "scripts/ds_tokens.py" emit-css > scripts/out/tokens.css
python3 "scripts/ds_tokens.py" lint
zsh "scripts/typecheck-ds.sh"
```

`contrast` prints the token table and the 43-pair WCAG table and exits non-zero on any failure or
any out-of-gamut OKLCH value. `emit-css` prints the `:root` block. `lint` checks four things: every
color token has a CSS variable that the guide actually uses and a backticked mention in this file;
every numeric token has a CSS variable in the guide and a `Enum.name` mention here; the product
name appears in no token file but `Brand.swift`; and the `:root` block pasted into the guide is
byte-identical to the current `emit-css` output. Usage is counted by exact variable name and only
outside HTML comments, so a token named in a comment does not count as consumed. Three tokens the
guide declares but cannot consume are printed as `EXCEPTION` lines on every run and are listed in
[§14](#14-token-index); `lint` also prints a `WARNING` while `DSIconCredits.entries` is still empty.
The script's module docstring now states all of this, the `EXCEPTION` and `WARNING` lines included,
so `python3 "scripts/ds_tokens.py"` with no argument prints that description to stderr and exits 1
rather than guessing a command. The docstring and this section are meant to agree; the docstring
ships with the script, so it wins if they ever stop agreeing.

`scripts/typecheck-ds.sh` type-checks the nine Swift files against the iOS 17 simulator SDK without
an Xcode project; it pins `DEVELOPER_DIR` to Xcode.app, because `xcode-select -p` on this machine
points at CommandLineTools, which carries no iOS SDK.

### Prefix rule

Twenty-two types are declared under `DesignSystem/`. Twenty carry the prefix: `DSColor`, `DSFont`,
`DSTextRole`, `DSSpace`, `DSRadius`, `DSGrid`, `DSSize`, `DSSwipe`, `DSShadow`, `DSLayer`,
`DSMotion`, `DSPressStyle`, `DSHaptic`, `DSIconRef`, `DSIcon`, `DSIconCredit`, `DSIconCredits`,
`DSFace`, `DSBlock`, and the `private` `DSHapticModifier`, which no call site ever names. Two do
not, each for a reason ADR-002 states: `VerdictColorSet` is a value the tokens hold rather than a
namespace of tokens, and `Brand` is the one place the product name is typed. View modifiers are
`.dsType`, `.dsShadow`, `.dsHaptic` and `.dsFocusRing`, plus the button style `.dsPress`. CSS
variables carry no brand prefix (`--color-ink`, not `--sift-color-ink`). `Brand.swift` is the only
file under `DesignSystem/` that types the product name, and that is the whole of what the lint
enforces. Prose names it where prose must: the title line of this document, the ADR bodies that
quote screen copy, and `design-system.html`. In code, including every copy string below, it is an
interpolation of `Brand.name`, so a rename is a one-line change plus that prose (ADR-002).

**Correction, 2026-09-24.** This rule used to name sixteen types and stop. Read off the Swift files,
three DS-prefixed types were missing: `DSPressStyle` (`DSMotion.swift`, the shared `ButtonStyle`
behind every press), and `DSIconCredit` and `DSIconCredits` (`DSIcon.swift`, the CC BY credit row
and the array the credits screen reads). The `private` `DSHapticModifier` was unaccounted for, the
modifier list was missing `.dsPress`, and `README.md` was named as prose carrying the product name
when it does not. The corrected inventory above is twenty-two types, which is what ADR-002 and P-11
count, and it is a count worth re-deriving rather than trusting:
`grep -rhoE '^(public |private |internal )?(enum|struct|class|actor) [A-Za-z_]+' Sift/DesignSystem/*.swift | sort`
printed twenty-two declarations on 2026-09-24, of which `Brand` and `VerdictColorSet` are the two
without the prefix.

---

## 1. Color

### Model

Every color is one fixed `oklch(L, C, H)` value, optionally with an alpha. There is no light/dark
pair, because there is no dark mode: the app is light only and the root view pins
`.preferredColorScheme(.light)` (ADR-006). Hex is derived by the script, never typed. OKLCH is used
because lightness is perceptual, so a lightness number predicts contrast; the script rejects any
value that falls outside the sRGB gamut.

Palette lineage: the poster palette from the two owner reference boards — tomato, cobalt, golden
yellow, mint, violet, lime, pink, lavender on white, with a navy ink (ADR-004, ADR-005).

### Surfaces

| Token | Value | Use |
|---|---|---|
| `canvas` | `oklch(1 0 0)` | Screen background. Pure white. Cards separate from it by shadow, not by tint. |
| `surface` | `oklch(1 0 0)` | Cards, sheets, the letterbox behind a screenshot. Pure white so a screenshot is never tinted. |
| `surfaceRaised` | `oklch(0.935 0 0)` | Secondary button fill, segmented-control track, list rows. |
| `toast` | `oklch(0.25 0.05 285)` | The toast capsule. Navy; its text is `onToast`. |
| `chip` | `oklch(1 0 0 / 0.9)` | Translucent chip over a screenshot (the date caption), with a system blur behind it. |

`canvas` and `surface` are both pure white by owner decision (2026-09-23). They stay two tokens
because they answer different questions: `canvas` is "what is behind everything", `surface` is
"what is this card made of". If a future version tints one, only one has to change.

`chip` is white at 90 % opacity. That alpha is the floor: over a pure-black screenshot it still
carries `ink` at 12.89:1 (the `chip over black` row of the contrast table). Under `reduceTransparency` the chip
becomes solid `surface`.

### Ink ramp

| Token | Value | Use |
|---|---|---|
| `ink` | `oklch(0.25 0.05 285)` | Primary text and icons. Navy, not black — from the reference board's button. |
| `ink2` | `oklch(0.45 0.03 285)` | Secondary text, captions, chrome icons. 6.19:1 on `surfaceRaised`, the tightest of the three surfaces. |
| `inkMuted` | `oklch(0.51 0.02 285)` | Placeholder and disabled meta. L .51 is the ceiling that still clears 4.5:1 on `surfaceRaised`, where it measures 4.77. |
| `onToast` | `oklch(1 0 0)` | Text on the toast capsule. |
| `onImage` | `oklch(1 0 0)` | Text and icons on the viewer's black bars only. |

`inkMuted` means quiet, not small. A muted line is still set at `body` or `caption` size; it never
becomes a reason to shrink type.

**Correction, 2026-09-24.** The `DSColor` doc comments rounded `ink2` on `surfaceRaised` to "6.0" and
gave `inkMuted` no measurement at all. The generated table is the authority: its `ink2` on
`surfaceRaised` row reads 6.19 and its `inkMuted` on `surfaceRaised` row reads 4.77. Both Swift
comments now carry those values, and the two cells above repeat them, so a reader who starts in
either place lands on the same number.

### Accent

| Token | Value | Use |
|---|---|---|
| `accent` | `oklch(0.25 0.05 285)` | Primary button fill. Identical to `ink` by design. |
| `onAccent` | `oklch(1 0 0)` | Labels and glyphs on `accent`, and white copy on the violet block. |
| `focus` | `ink` at 60 % | Focus ring for keyboard and Full Keyboard Access, and the default value of `.dsFocusRing`'s `color:` parameter. At 45 % the ring measured 2.79:1 on white, below the 3:1 non-text bar, so it is denser than the reference's. It is measured on the neutral surfaces only; a control on a color block passes `DSBlock.focusRing` instead. |

The accent is monochrome (ADR-005). There is no green success token and no red error token:
success is a haptic plus a sentence, an error is `ink` text with the warning glyph. A red error
color would collide with TRASH, and any saturated accent would compete with the three verdict
colors, which are the only colors that carry meaning.

### Verdicts

Each verdict owns three colors through `VerdictColorSet`: `main` fills, `on` sits on `main`, `soft`
tints (ADR-004).

| Verdict | Direction | Destination | `main` | `on` | `soft` |
|---|---|---|---|---|---|
| Trash | left | the app's own Trash screen | `trash.main` `oklch(0.65 0.19 38)` tomato | `trash.on` white | `trash.soft` `oklch(0.93 0.036 38)` |
| Archive | right | the Photos album `Brand.archiveAlbumTitle` | `archive.main` `oklch(0.5 0.24 272)` cobalt | `archive.on` white | `archive.soft` `oklch(0.93 0.029 272)` |
| Fave | up | Photos favorites (`isFavorite`) | `fave.main` `oklch(0.85 0.16 92)` golden yellow | `fave.on` navy | `fave.soft` `oklch(0.95 0.07 95)` |

Why these three hues and not red / green / yellow: right-means-green is intuitive, but red against
green is the most common color-vision collision. Cobalt stays apart from both tomato and yellow on
a deuteranope's axis. Tomato and yellow do fall on the same side of it — accepted, because hue is
the third channel here, after direction and after the word on the stamp.

### Expressive palette

Five colors that never carry verdict meaning and are never used for chrome. They exist for
full-bleed blocks on onboarding and empty states (ADR-016).

| Token | Value | Block |
|---|---|---|
| `mint` | `oklch(0.8 0.1 165)` | Trash empty |
| `violet` | `oklch(0.48 0.16 285)` | Permission denied (white ink) |
| `lime` | `oklch(0.94 0.2 118)` | All done |
| `pink` | `oklch(0.87 0.08 335)` | Favorites empty |
| `lavender` | `oklch(0.72 0.14 305)` | Archive empty |

Two blocks use colors from outside this list, and both are deliberate: onboarding is
`trash.main` because the reference board's hero block is tomato and onboarding precedes any
verdict, so the color cannot yet be read as "trash"; the limited-access interstitial is
`fave.soft`, a pale tint that reads as a notice rather than a state. The full mapping is in
[§9](#9-illustration).

### Overlays and shadows

| Token | Value | Use |
|---|---|---|
| `scrim` | `ink` at 35 % | Modal dim behind sheets. |
| `shadowNear` | `ink` at 10 % | Layer 1 of both shadow levels. |
| `shadowFar` | `ink` at 5 % | Layer 2 of both shadow levels. |

### Usage rules

1. **On a `main` fill, only the stamp word and the glyphs may use `on`.** WCAG large text starts
   at 24 pt regular or 19 pt bold; bold at any size is not large text. On a verdict `main` fill the
   3:1 bar therefore covers exactly two things: the stamp word, set at 32 pt in
   `DSTextRole.stamp`, and the icon glyphs. Every label at `body`, `label` or `labelSmall` size on
   a verdict fill is `ink` instead, which measures 4.61 on `trash.main` and 10.20 on `fave.main`.
   White on `archive.main` is the one measured exception, and it is the only one: of the two white
   `on` colors it is the one that also clears 4.5 as normal text, at 6.57, so a white label on
   cobalt is legal at label size where white on tomato (3.51) is not. `fave.on` clears 4.5 too, at
   10.20, but that is the rule rather than an exception to it: `fave.on` *is* `ink`, the same
   `oklch(0.25 0.05 285)` navy. Weight is not the gate here, color is: the destructive button
   "Delete all permanently" carries `DSTextRole.label` at 16 pt bold, which is below the 19 pt bold
   floor, so it is navy on tomato at 4.61 rather than white on tomato at 3.51. The rows to read are
   `large text · stamp word (32 pt) and button glyph on main`,
   `text · destructive button label (16 pt bold) and onboarding copy on tomato`, and
   `text · white label on a cobalt fill`.
2. **Text on `soft` is `ink`.** Never `main` text on a `soft` tint, never `on` text on `soft`. A
   soft tint is a background for navy, nothing else.
3. **The yellow exemption.** `fave.main` cannot reach 3:1 against white (it measures 1.58:1)
   without turning ochre. Its *edge* therefore never carries meaning: the navy glyph and the word
   FAVE do, at 10.20:1. The contrast table prints both `fave.main` edge rows as informational for
   this reason. No other token gets this exemption.
4. **Color is never the only channel.** Every verdict is a direction, a glyph and a word before it
   is a hue.
5. **No borders.** Surfaces separate by tint and whitespace. The focus ring is the only stroke in
   the system.
6. **Regular-weight copy on `main` is allowed when it is `ink`.** Nothing in this system forbids a
   regular weight on a verdict fill; what is forbidden is a foreground that cannot reach 4.5. That
   is why `DSBlock.onboarding` sets `body` copy in `ink` on `trash.main` at 4.61 and is legal, and
   why the same block in `trash.on` would not be.

### 60 / 30 / 10

- **60 — white.** `canvas` and `surface`. The screenshot is the subject; the app is the mat around
  it.
- **30 — navy.** `ink`, `ink2`, `accent`, `toast`. All type, all chrome icons, all primary buttons.
- **10 — color.** A verdict `main` fill appears in exactly four places, counted against
  [§10](#10-components) and [§11](#11-screens): the three `VerdictStamp` pills, the three circles of
  `VerdictButtonRow`, the Trash count badge in the Review header, and the destructive button, which
  is a `trash.main` fill carrying a navy `ink` label at 4.61:1 (docked on Trash, and again inside
  `PurgeAllSheet`). Nothing else in the chrome is saturated. The pale `soft` tints are not counted
  here: a `soft` tint is a background for `ink`, not a saturated fill.
- **Blocks are the exception, and they are full-bleed or absent.** An expressive color block covers
  the whole screen or does not appear at all; it is used on onboarding and on empty states only.
  There is no "accent panel" version of a block.

**Correction, 2026-09-24.** The 10 % rule used to name three places and then close with "nothing
else in the chrome is saturated", which made the sentence contradict itself: the destructive button
is a `trash.main` fill and it is chrome. P-06 in `DESIGN_PRINCIPLES.md` and the P-06 line of
`PRINCIPLES_CHECKLIST.md` both name four. Counted here against the component and screen tables the
answer is four, and the fourth is the destructive button.

### Measured contrast

Generated by `python3 "scripts/ds_tokens.py" contrast`. Pasted verbatim; do not edit by hand.

<!-- BEGIN generated: scripts/out/contrast.md -->

## Color tokens (OKLCH → sRGB)

| Token | OKLCH | Hex | Note |
|---|---|---|---|
| `canvas` | oklch(1 0 0) | #ffffff |  |
| `surface` | oklch(1 0 0) | #ffffff |  |
| `surfaceRaised` | oklch(0.935 0 0) | #e9e9e9 |  |
| `toast` | oklch(0.25 0.05 285) | #1f1e38 |  |
| `chip` | oklch(1 0 0 / 0.9) | #ffffff @0.9 |  |
| `ink` | oklch(0.25 0.05 285) | #1f1e38 |  |
| `ink2` | oklch(0.45 0.03 285) | #535366 |  |
| `inkMuted` | oklch(0.51 0.02 285) | #656571 |  |
| `onToast` | oklch(1 0 0) | #ffffff |  |
| `onImage` | oklch(1 0 0) | #ffffff |  |
| `accent` | oklch(0.25 0.05 285) | #1f1e38 |  |
| `onAccent` | oklch(1 0 0) | #ffffff |  |
| `focus` | oklch(0.25 0.05 285 / 0.6) | #1f1e38 @0.6 | derived from `ink` |
| `trash.main` | oklch(0.65 0.19 38) | #eb5927 |  |
| `trash.on` | oklch(1 0 0) | #ffffff |  |
| `trash.soft` | oklch(0.93 0.036 38) | #ffe0d7 |  |
| `archive.main` | oklch(0.5 0.24 272) | #3d44e8 |  |
| `archive.on` | oklch(1 0 0) | #ffffff |  |
| `archive.soft` | oklch(0.93 0.029 272) | #e1e7fc |  |
| `fave.main` | oklch(0.85 0.16 92) | #f3c935 |  |
| `fave.on` | oklch(0.25 0.05 285) | #1f1e38 |  |
| `fave.soft` | oklch(0.95 0.07 95) | #fdefba |  |
| `mint` | oklch(0.8 0.1 165) | #7cd2ae |  |
| `violet` | oklch(0.48 0.16 285) | #5849b2 |  |
| `lime` | oklch(0.94 0.2 118) | #e0fc41 |  |
| `pink` | oklch(0.87 0.08 335) | #f6c1e9 |  |
| `lavender` | oklch(0.72 0.14 305) | #b98cea |  |
| `scrim` | oklch(0.25 0.05 285 / 0.35) | #1f1e38 @0.35 |  |
| `shadowNear` | oklch(0.25 0.05 285 / 0.1) | #1f1e38 @0.1 |  |
| `shadowFar` | oklch(0.25 0.05 285 / 0.05) | #1f1e38 @0.05 |  |

## Contrast (WCAG 2.x) — text ≥ 4.5 · bold/large/non-text ≥ 3 · informational rows are exempt

| # | Foreground | Background | Use | Min | Ratio | Result |
|---|---|---|---|---|---|---|
| 1 | `ink` | `canvas` | text | 4.5 | 16.16 | PASS |
| 2 | `ink` | `surface` | text | 4.5 | 16.16 | PASS |
| 3 | `ink` | `surfaceRaised` | text | 4.5 | 13.35 | PASS |
| 4 | `ink2` | `canvas` | text | 4.5 | 7.49 | PASS |
| 5 | `ink2` | `surface` | text | 4.5 | 7.49 | PASS |
| 6 | `ink2` | `surfaceRaised` | text | 4.5 | 6.19 | PASS |
| 7 | `inkMuted` | `canvas` | text | 4.5 | 5.77 | PASS |
| 8 | `inkMuted` | `surface` | text | 4.5 | 5.77 | PASS |
| 9 | `inkMuted` | `surfaceRaised` | text | 4.5 | 4.77 | PASS |
| 10 | `onToast` | `toast` | text | 4.5 | 16.16 | PASS |
| 11 | `onAccent` | `accent` | text · primary button label | 4.5 | 16.16 | PASS |
| 12 | `onImage` | `black` | text · viewer bars | 4.5 | 21.00 | PASS |
| 13 | `ink` | `chip over white` | text · chip over a white screenshot | 4.5 | 16.16 | PASS |
| 14 | `ink` | `chip over black` | text · chip over a black screenshot | 4.5 | 12.89 | PASS |
| 15 | `ink` | `surfaceRaised` | non-text · secondary button glyph | 3 | 13.35 | PASS |
| 16 | `focus` | `canvas over canvas` | non-text · focus ring on canvas | 3 | 4.34 | PASS |
| 17 | `focus` | `surfaceRaised over surfaceRaised` | non-text · focus ring on a raised control | 3 | 4.06 | PASS |
| 18 | `accent` | `canvas` | non-text · primary button edge on canvas | 3 | 16.16 | PASS |
| 19 | `onAccent` | `ink` | text · CTA pill label on a block, the pill being the block's ink | 4.5 | 16.16 | PASS |
| 20 | `accent` | `onAccent` | text · CTA pill label on the denied block, the pill being white | 4.5 | 16.16 | PASS |
| 21 | `ink2` | `canvas` | non-text · chrome icons | 3 | 7.49 | PASS |
| 22 | `trash.on` | `trash.main` | large text · stamp word (32 pt) and button glyph on main | 3 | 3.51 | PASS |
| 23 | `ink` | `trash.soft` | text · chip on soft | 4.5 | 13.01 | PASS |
| 24 | `archive.on` | `archive.main` | large text · stamp word (32 pt) and button glyph on main | 3 | 6.57 | PASS |
| 25 | `ink` | `archive.soft` | text · chip on soft | 4.5 | 13.12 | PASS |
| 26 | `fave.on` | `fave.main` | large text · stamp word (32 pt) and button glyph on main | 3 | 10.20 | PASS |
| 27 | `ink` | `fave.soft` | text · chip on soft | 4.5 | 14.01 | PASS |
| 28 | `trash.main` | `canvas` | non-text · button / badge edge on canvas | 3 | 3.51 | PASS |
| 29 | `trash.main` | `white` | non-text · stamp pill on a white screenshot | 3 | 3.51 | PASS |
| 30 | `archive.main` | `canvas` | non-text · button / badge edge on canvas | 3 | 6.57 | PASS |
| 31 | `archive.main` | `white` | non-text · stamp pill on a white screenshot | 3 | 6.57 | PASS |
| 32 | `fave.main` | `canvas` | informational · yellow edge is exempt, the navy word carries meaning (ADR-004) | — | 1.58 | info |
| 33 | `fave.main` | `white` | informational · same exemption on a white screenshot | — | 1.58 | info |
| 34 | `ink` | `trash.main` | text · destructive button label (16 pt bold) and onboarding copy on tomato | 4.5 | 4.61 | PASS |
| 35 | `archive.on` | `archive.main` | text · white label on a cobalt fill | 4.5 | 6.57 | PASS |
| 36 | `ink` | `fave.main` | text · copy on a yellow block | 4.5 | 10.20 | PASS |
| 37 | `ink` | `mint` | text · copy on the mint block | 4.5 | 9.02 | PASS |
| 38 | `ink` | `lime` | text · copy on the lime block | 4.5 | 13.99 | PASS |
| 39 | `ink` | `pink` | text · copy on the pink block | 4.5 | 10.56 | PASS |
| 40 | `ink` | `lavender` | text · copy on the lavender block | 4.5 | 6.18 | PASS |
| 41 | `onAccent` | `violet` | text · white copy on the violet block | 4.5 | 6.95 | PASS |
| 42 | `onAccent` | `trash.main` | large text · white stamp word on tomato — never a button label | 3 | 3.51 | PASS |
| 43 | `surfaceRaised` | `canvas` | informational · raised fill vs canvas (tint separation, no border) | — | 1.21 | info |

43 pairs · 0 failure(s)

<!-- END generated -->

Six rows deserve a note. The `ink` on `trash.main` row, 4.61:1, now does triple duty: it is why
regular-weight copy is allowed on the onboarding block, it is why the destructive button's 16 pt
bold label is navy rather than white, and it is the worst case of both the block CTA pill and the
block focus ring, each of which is the block's own ink ([§9 Rules](#rules)). It clears 4.5:1 with
almost no margin, so nothing lighter than `ink` may be set on tomato. Two rows were added for the
CTA pill's label and both measure 16.16:1: `onAccent` on `ink`, the label on the pill of the six
blocks whose ink is `ink`, and `accent` on `onAccent`, the label on the pill of `denied`, whose ink
is `onAccent`. No row was added for the pill *against* its block or for the ring against its block,
because each of those is the same pair as that block's copy row, which the table already enforces at
the stricter 4.5 text bar. The two `focus` rows, 4.34:1 on `canvas` and 4.06:1 on `surfaceRaised`,
are what the 60 % alpha bought; at 45 % the ring measured 2.79:1 and missed the 3:1 non-text bar. And
`surfaceRaised` against `canvas` at 1.21:1 is printed as informational because that is intentional. A
raised surface is found by its shape and its shadow, not by an edge, and adding a border to reach 3:1
would violate the no-borders rule.

Rows are named here by their token pair, or by the quoted string in the table's `Use` column when one
pair appears twice, and never by the number in the `#` column. That number is a position in generated
output: adding a pair renumbers every row below it, so a citation to it rots on the next `contrast`
run. `grep 'white label on a cobalt fill' scripts/out/contrast.md` still finds its row; "row 35" only
used to.

---

## 2. Typography

### Two voices

**Display — Forager Bold Overlap.** One weight for all four display roles: `display`, `headline`,
`title` and `stamp`. Forager Overlap has no cut heavier than Bold, so `DSFont.displayBold` and
`DSFont.displayBlack` hold the same PostScript name, `Forager-BoldOverlap`. It is the poster voice:
statements, screen titles, the three stamp words.

**Text — Pretendard.** Regular, Medium, SemiBold, Bold. Everything a user reads rather than
recognizes: body copy, buttons, chips, captions, the counter.

### License note (ADR-003)

Forager (Mark Simonson Studio) ships through Adobe Fonts, whose license covers web and desktop
use but not embedding in a mobile app; an app license is a separate purchase from the foundry.
Pretendard is SIL OFL and is bundled.

Consequence: the app does not bundle Forager yet. `DSFont.availableDisplayNames` is a
`Set<String>` built once in a closure that probes each display name on its own —
`UIFont(name: "Forager-BoldOverlap", size: 12)` — and `DSFont.resolvedDisplay(_:)` returns that name
when the set contains it and `Pretendard-Bold` when it does not. Both
`DSFont.display(_:size:relativeTo:)` and `DSFont.displayFixed(_:size:)` resolve through it. Titles
are therefore slightly different in the app from the guide until the license lands, but the
hierarchy — size and weight — is identical either way. Each name is probed separately, so a future
display family whose cuts arrive one at a time still falls back per cut instead of dropping the
whole display voice to the system font.

**Correction, 2026-09-24.** This paragraph used to describe `DSFont.displayAvailability`, a
dictionary literal keyed by constant, and [§15](#15-open-questions) item 8 used to call its
duplicate key a defect that costs an extra lookup. The cost was stated wrongly, and so was the
timing. `DSFont.displayBold` and `DSFont.displayBlack` hold the same string,
`Forager-BoldOverlap`, and a Swift dictionary literal with duplicate keys traps at *construction*,
so the app would have crashed on the first display role it rendered rather than paying for a
redundant entry. `DSTypography.swift` now builds `DSFont.availableDisplayNames` as a `Set` inside a
closure that inserts each probed name, which cannot trap and keeps the per-cut fallback.

The HTML guide loads Forager from Typekit kit `blt4ith` (family `forager-overlap`, weights 400 and
700; there is no heavier cut, so every display role renders at 700 on the web). The stylesheet link
carries a `?v=` cache-buster because Typekit serves the kit with `max-age=600`: a family added to or
changed in the kit does not reach a reader for ten minutes unless that number changes. Bump it on
every kit edit.

### Roles

Ten of the eleven roles bind to a Dynamic Type text style through `relativeTo:` and scale with it.
`stamp` is the documented exception: it binds to no text style, because
`DSTextRole.stampFont(size:)` returns a fixed-size font and the call site owns
`@ScaledMetric(relativeTo: .largeTitle)` — see [Stamp sizing](#stamp-sizing). Tracking is in points;
line spacing is *extra* leading added to the font's own metrics.

| Role | Face | Size | `relativeTo` | Tracking | Line spacing | Use |
|---|---|---|---|---|---|---|
| `display` | Forager Bold Overlap | 34 | `.largeTitle` | +1.02 | 0 | Wordmark, face captions on color blocks |
| `headline` | Forager Bold Overlap | 28 | `.title` | +0.84 | 0 | Permission title, empty-state title |
| `title` | Forager Bold Overlap | 24 | `.title2` | +0.72 | 0 | Screen titles (Trash, Library) |
| `counter` | Pretendard Bold, `monospacedDigit()` | 22 | `.title2` | 0 | 0 | Progress "12 / 340" |
| `subhead` | Pretendard SemiBold | 18 | `.title3` | −0.18 | 2 | Card names, sheet titles |
| `body` | Pretendard Regular | 16 | `.body` | −0.16 | 5 | Copy |
| `label` | Pretendard Bold | 16 | `.headline` | 0 | 3 | Buttons, segments |
| `labelSmall` | Pretendard SemiBold | 14 | `.subheadline` | 0 | 3 | Chips, secondary buttons |
| `caption` | Pretendard Medium | 14 | `.footnote` | +0.14 | 3 | Dates, hints |
| `buttonCaption` | Pretendard Bold | 12 | `.caption2` | 0 | 3 | Captions under the verdict buttons only |
| `stamp` | Forager Bold Overlap | 32 | none (fixed size) | +2 | 0 | TRASH / ARCHIVE / FAVE pill labels, uppercase |

Tracking runs in two directions. The display roles are tracked **out**, by 3 % of their size
(30/1000 em): Forager Overlap's strokes intentionally run into each other, so the display voice is
opened rather than optically tightened. `subhead` and `body` tighten by 1 % of their size, `caption`
opens by 1 %, and the stamp opens by a flat 2 pt because uppercase display type at poster size
closes up otherwise.

`label` is Pretendard **Bold**, not SemiBold, and that is a typographic decision, not a contrast
one. Bold buys no contrast relief at this size: WCAG large text starts at 24 pt regular or 19 pt
bold, so a 16 pt bold label owes the full 4.5:1 like any other body-size line. White on `trash.main`
is 3.51:1, which is legal for the 32 pt stamp word and for the glyphs and for nothing else; a 16 pt
label on tomato is `ink` at 4.61:1. See [§1 Usage rules](#usage-rules).

### Stamp sizing

`DSTextRole.stampBaseSize` is 32 and `DSTextRole.stampMaxSize` is 44. Dynamic Type for the stamp is
owned by the call site, not by the role:

```swift
@ScaledMetric(relativeTo: .largeTitle) private var stampSize = DSTextRole.stampBaseSize
Text("TRASH").font(DSTextRole.stampFont(size: stampSize))
```

`DSTextRole.stampFont(size:)` applies `min(size, DSTextRole.stampMaxSize)` and then returns a
**fixed**-size font. Fixed is the whole point: a `relativeTo:` font would scale an already-scaled
value a second time, and the 44 pt cap would leak past 44 at accessibility sizes. `DSTextRole.stamp`
still has a `font`, which is what `.dsType(.stamp)` applies, but that is the unscaled 32 pt form and
belongs to previews and to this guide rather than to the running screen. The cap exists because the
stamp sits inside the card: past 44 pt the word starts colliding with the opposite corner on a
small device, and the stamp is decorative anyway — it is `accessibilityHidden`, and VoiceOver users
get the verdict from the custom action they invoked and from the announcement after it.

### The caption rule

Hierarchy moves size and weight in the same direction. `caption` is never used as a rung *above*
`body`. A smaller-but-bolder line reads as no hierarchy at all, and at accessibility text sizes
`.footnote` and `.body` converge, so the distinction disappears exactly when it is needed most. If
something must outrank `body`, it gets `subhead`.

### The tabular counter

`counter` calls `.monospacedDigit()`. The progress string changes on every commit; with
proportional digits the slash and the total shift horizontally each time and the header appears to
twitch. Tabular figures pin it. The counter also uses `.contentTransition(.numericText())` so the
changed digit rolls rather than cuts.

### PostScript names to verify

`DSFont` declares four text names and two display constants that hold one name between them. The
text names are known good because Pretendard is already bundled; the display name is the foundry's
and is unverified until the file exists.

| Constant | PostScript name | Status |
|---|---|---|
| `DSFont.displayBold` | `Forager-BoldOverlap` | verify with `UIFont.familyNames` when the app license lands |
| `DSFont.displayBlack` | `Forager-BoldOverlap` | the same face; Forager Overlap has no heavier cut |
| `DSFont.textRegular` | `Pretendard-Regular` | bundled |
| `DSFont.textMedium` | `Pretendard-Medium` | bundled |
| `DSFont.textSemibold` | `Pretendard-SemiBold` | bundled |
| `DSFont.textBold` | `Pretendard-Bold` | bundled |

### HTML equivalents

The guide is a web page with its own responsive scale: eleven CSS role variables, one per
`DSTextRole`, which is what the guide's own prose claims ("Eleven roles, mirroring `DSTextRole`").
It is not a five-rung scale and no role is folded into another. These sizes live in the guide's own
CSS, not in the Swift tokens; they exist so the printed guide reads correctly on a laptop and on a
phone (ADR-020, single breakpoint at `DSGrid.breakpoint`). Values below are the CSS `font` shorthand
as declared, `weight size/line-height`.

| `DSTextRole` | CSS variable | Desktop ≥ 1200 px | Mobile < 1200 px |
|---|---|---|---|
| `display` | `--t-display` | 700 48px/1.06 | 700 34px/1.08 |
| `headline` | `--t-headline` | 700 32px/1.14 | 700 28px/1.16 |
| `title` | `--t-title` | 700 26px/1.2 | 700 24px/1.2 |
| `counter` | `--t-counter` | 700 22px/1.2 | unchanged |
| `subhead` | `--t-subhead` | 600 22px/1.25 | 600 18px/1.3 |
| `body` | `--t-body` | 400 18px/1.4 | 400 16px/1.4 |
| `label` | `--t-label` | 700 16px/1.2 | unchanged |
| `labelSmall` | `--t-label-sm` | 600 14px/1.2 | unchanged |
| `caption` | `--t-caption` | 500 16px/1.4 | 500 14px/1.4 |
| `buttonCaption` | `--t-btn-cap` | 700 12px/1.2 | unchanged |
| `stamp` | `--t-stamp` | 700 32px/1 | unchanged |

Three notes. Six of the eleven are re-declared inside the `max-width: 1199.98px` media query
(`--t-display`, `--t-headline`, `--t-title`, `--t-subhead`, `--t-body`, `--t-caption`); the other
five hold their desktop values at every width, because `--t-counter`, `--t-label`, `--t-label-sm`
and `--t-btn-cap` are already 22 px or smaller, and `--t-stamp` is a poster element that is meant to
be 32 px on a phone too. A twelfth variable, `--t-display-size`, carries the display size on its own (48 px desktop, 34 px
mobile) for the hero heading, which borrows `--t-headline` and overrides its size. And four
variables resolve against the display family (`--t-display`, `--t-headline`, `--t-title`,
`--t-stamp`); all four ask for weight 700, because kit `blt4ith` exposes `forager-overlap` at 400
and 700 and there is no heavier cut. No role in the guide asks for 900. Their tracking matches the
Swift roles: `.t-display`, `.t-headline` and `.t-title` carry `letter-spacing: 0.03em`, the web
spelling of the +3 % in the table above. `.t-stamp` carries `0.06em`, in all three places the guide
sets a stamp, and that is a rounding rather than an equality: 0.06 em at 32 px is 1.92 px, not 2 px.
The exact web equivalent of the Swift flat `+2` at `DSTextRole.stampBaseSize` 32 is `0.0625em`. The
0.08 px the guide gives away is under a device pixel at any sensible zoom, so the declared value
stands and the difference is recorded here rather than asserted away.

---

## 3. Spacing, radius, grid

Inherited verbatim from the owner's previous design system (ADR-018). It is proven, and the guide
format is the same, so re-deriving a scale would only create two scales.

### Spacing

| Token | Value | Use |
|---|---|---|
| `DSSpace.s1` | 6 | Icon-to-text gap, padding inside chips |
| `DSSpace.s2` | 8 | Small gaps, mobile gutter |
| `DSSpace.s3` | 12 | Input and button inner padding |
| `DSSpace.s4` | 16 | Default gap, mobile screen margin |
| `DSSpace.s5` | 24 | Card padding, desktop gutter |
| `DSSpace.s6` | 28 | Wide padding |
| `DSSpace.s7` | 32 | Section separation |

Anything not on this scale is a mistake, not a nuance. Two values in the approved interaction spec
were off-scale (a 20 pt stamp inset and a 20 pt gap between verdict buttons); both are snapped to
`DSSpace.s5` here, because ADR-018 inherits the scale verbatim and the scale has no 20.

### Radius

| Token | Value | Use |
|---|---|---|
| `DSRadius.xs` | 6 | Chips, badges, thumbnails |
| `DSRadius.sm` | 8 | Secondary controls |
| `DSRadius.md` | 12 | Buttons, inputs, segmented control |
| `DSRadius.lg` | 16 | Cards |
| `DSRadius.xl` | 24 | The screenshot card, sheets |
| `DSRadius.pill` | 999 | Stamps, verdict buttons, toast, CTA pills |

Two rules govern which one to pick:

1. **Radius tracks the element's inner padding.** A control padded by `DSSpace.s3` takes
   `DSRadius.md`; a card padded by `DSSpace.s5` takes `DSRadius.xl`.
2. **Nested radius = outer radius − gap, clamped to the scale.** A thumbnail inset by `DSSpace.s2`
   inside a `DSRadius.md` container computes 12 − 8 = 4, and 4 is not on the scale. There is no
   token below `DSRadius.xs`, which is 6, so the value is clamped **up** to 6 rather than rounded
   down to something that does not exist. In this one case the inner radius therefore lands 2 pt
   above what the arithmetic asks for and the corners are nearly, not exactly, concentric. That is
   accepted: it keeps the radius on the scale, and 6 is still well below the container's 12, which
   is the constraint that actually matters. Concentric corners look wrong when the inner radius is
   equal to or larger than the outer one.

All rounded shapes use `style: .continuous`.

### Grid

One breakpoint. Desktop applies to the style guide; mobile applies to the app.

| Token | Value | Use |
|---|---|---|
| `DSGrid.breakpoint` | 1200 | The single breakpoint, in px, for the guide |
| `DSGrid.desktopColumns` | 14 | Guide columns; the two end columns act as margins, content lives in 2–13 |
| `DSGrid.desktopGutter` | 24 | Guide gutter |
| `DSGrid.mobileColumns` | 4 | App columns |
| `DSGrid.mobileMargin` | 16 | App screen margin, left and right |
| `DSGrid.mobileGutter` | 8 | App gutter |

The app grid is four columns with a 16 pt margin: the card spans all four, the thumbnail grids in
Trash and Library use three equal columns (`DSSize.gridColumns`) with a 4 pt gutter
(`DSSize.thumbnailGutter`) rather than the layout gutter, because a photo grid wants tighter
spacing than a content grid.

---

## 4. Sizes

| Token | Value | Use |
|---|---|---|
| `DSSize.tapMin` | 44 | Minimum hit target. Pad the hit area, never the glyph. |
| `DSSize.verdictButton` | 64 | Diameter of the Trash and Archive circles |
| `DSSize.faveButton` | 56 | Diameter of the Fave circle — smaller on purpose |
| `DSSize.faveButtonRaise` | 8 | How far the Fave circle sits above the other two |
| `DSSize.rewindButton` | 44 | Diameter of the rewind button |
| `DSSize.cardInset` | 12 | Letterbox inset between the card edge and the screenshot |
| `DSSize.thumbnailGutter` | 4 | Gutter in the Trash and Library grids |
| `DSSize.stackOffsetY` | 14 | Vertical offset per card behind the front card |
| `DSSize.stackScaleStep` | 0.06 | Scale reduction per card behind the front card |
| `DSSize.stampFaveRaise` | 0.12 | The FAVE stamp's centre sits this fraction of the card height above the card's centre |
| `DSSize.iconVerdict` | 28 | Glyph inside a verdict button |
| `DSSize.iconChrome` | 24 | Header and toolbar glyphs |
| `DSSize.iconInline` | 20 | Glyphs set inside a line of text |
| `DSSize.stampIcon` | 24 | Glyph leading the stamp word |
| `DSSize.focusRing` | 3 | Focus ring stroke width |
| `DSSize.gridColumns` | 3 | Columns in the Trash and Library grids |
| `DSSize.stackDepth` | 3 | Cards rendered in the stack, front card included |

The middle button is deliberately the odd one out: `DSSize.faveButton` is 8 pt smaller than
`DSSize.verdictButton` and raised by `DSSize.faveButtonRaise`, so the row of three reads as a
direction map — left, up, right — rather than as three equal choices.

The toast's dwell time is not a size. `DSSize.toastVisibleSeconds` used to restate
`DSMotion.toastVisible`, and a duration typed twice is drift waiting to happen, so it was deleted.
`DSMotion.toastVisible` (2.5 s) is now the only place the toast's visible duration is written, and
[§6 Durations](#durations) is where to read it. A view that needs to reserve room for the toast reads
the toast's own layout, never a duration.

---

### Opacity

One value applies to a whole control rather than to a color; a color's own alpha is a `DSColor`
token (`focus`, `scrim`).

| Token | Value | Use |
|---|---|---|
| `DSOpacity.disabled` | 0.45 | Disabled buttons, and Rewind with nothing to rewind. Never the only signal: the control also carries the disabled trait (P-19) |

## 5. Elevation and layering

### No borders

Surfaces separate by tint (`surfaceRaised` against `surface`) and by whitespace. There is exactly
one stroke in the system, the focus ring. This is inherited from the reference system and confirmed
by ADR-006.

### Shadows

Shadows exist only for things that **float**: the front card of the stack, a committed stamp, the
verdict buttons, the toast, and sheets. A thumbnail does not float. A segmented control does not
float. A color block does not float.

| Level | Layer 1 | Layer 2 | Direction |
|---|---|---|---|
| `DSShadow.floating` | `shadowNear`, radius 1.5, x 0, y 1 | `shadowFar`, radius 12, x 0, y 10 | down |
| `DSShadow.stack` | `shadowNear`, radius 3, x 0, y −2 | `shadowFar`, radius 10, x 0, y −8 | up |

`DSShadow.stack` casts **upward** so that a card behind the front card reads as lying underneath
it rather than hovering over it. In CSS terms the two layers of `DSShadow.floating` are
`0 1px 3px` at 10 % and `0 10px 24px -6px` at 5 % — SwiftUI's `radius` is roughly half the CSS
blur.

Both levels go through `.dsShadow(_:)`, which applies `compositingGroup()` before the shadow. Skip
it and SwiftUI shadows every child separately, so a card with a chip and a stamp on it grows a
visible halo around each one.

### Focus ring

`.dsFocusRing(_ focused: Bool, cornerRadius: CGFloat, color: Color = DSColor.focus)` strokes a
`RoundedRectangle` at `DSSize.focusRing` and pads by the negative of the same value, so the ring
sits *outside* the shape and never eats into the content. When not focused the line width is 0
rather than the overlay being removed, so the layout does not move. It appears for keyboard and Full
Keyboard Access only; touch never shows it.

**The colour is a parameter, not a constant.** The helper does not hard-code `DSColor.focus`; it
defaults to it, precisely because the ring is translucent and its ratio therefore depends on what it
sits on. A caller on a surface the default was not tuned for passes its own colour. Any statement
that the helper is fixed to `DSColor.focus` is out of date, and so is the strong form of the rule
that travelled with it: a surface does not need its own `focus`-over-surface row before it may host a
focusable control, it needs a ring colour that has been measured against it. `DSColor.focus` has that
measurement on exactly two surfaces, `canvas` at 4.34 and `surfaceRaised` at 4.06. A block has it
through `DSBlock.focusRing`, whose pair is the block's own copy row, and that row is the measurement
that covers the ring. The older form of the rule was written into two other documents, and both are
outside this one: ADR-021's Consequences paragraph, whose wording is "needs its own
`focus`-over-surface row in `PAIRS` before it may host a focusable control", and the P-19 paragraph in
`DESIGN_PRINCIPLES.md` that begins "The focus ring is measured like everything else". ADR-021 carries
a correction of its own that narrows the claim. Search those two strings rather than trusting this
sentence about the state of another file.

**On a color block the ring is not `focus`.** `DSBlock.focusRing` is the block's own ink at full
strength. `focus` is `ink` at 60 %, an alpha tuned over the neutral surfaces, and composited over a
saturated block it falls to 2.65 on `trash.main`, 2.92 on `lavender` and 1.71 on `violet`, all under
the 3:1 non-text bar. At full strength the ring is the same pair as the block's own copy, which the
contrast table already enforces at the stricter 4.5 text bar, so it clears 4.61 at worst (tomato)
and 14.01 at best (pale yellow). The width, `DSSize.focusRing` 3, does not change. See
[§9 Rules](#rules).

### Layer ladder

`DSLayer` is a `Double` scale because SwiftUI's `zIndex` takes a Double.

| Token | Value | What lives here |
|---|---|---|
| `DSLayer.base` | 0 | The card stack, grids, everything in flow |
| `DSLayer.sticky` | 100 | Sticky header, the docked verdict row |
| `DSLayer.dropdown` | 1000 | Popovers, context menus |
| `DSLayer.modal` | 2000 | Sheets and their `scrim` |
| `DSLayer.toast` | 3000 | The toast, always on top |

The gaps are large on purpose: a new layer can be inserted between two rungs without renumbering
the ladder.

---

## 6. Motion and swipe physics

Transform and opacity only — nothing animates a layout property. Entries ease out, exits are faster
than entries, and every animation goes through a `DSMotion.gated` overload, so Reduce Motion is
honored at one choke point instead of at every call site. There are two overloads.
`gated(_:reduce:)` returns `nil` and removes the animation. `gated(_:reduce:reduced:)` returns a
substitute instead, and the substitute is always a named token — `DSMotion.snapBackReduced` (linear
over `DSMotion.dur1`) or `DSMotion.crossFade` (linear over `DSMotion.fade`) — so the rule "never pass
a raw curve to `withAnimation`" holds for replacements exactly as it holds for removals.

### Durations

| Token | Value | Use |
|---|---|---|
| `DSMotion.dur1` | 0.12 s | Micro: press, focus, Reduce-Motion snap-back |
| `DSMotion.dur2` | 0.18 s | Standard UI: color and state changes, the stamp fade on rewind |
| `DSMotion.dur3` | 0.24 s | Surface transitions: sheet, card expand |
| `DSMotion.buttonFlick` | 0.28 s | Synthesized flick when a verdict comes from a button instead of a swipe |
| `DSMotion.exitMin` | 0.18 s | Fastest possible throw |
| `DSMotion.exitMax` | 0.32 s | Slowest possible throw |
| `DSMotion.fade` | 0.18 s | Cross-fades: next-card fade-in, cell removal, Reduce-Motion exit |
| `DSMotion.stampHoldReduced` | 0.25 s | Reduce Motion: how long the stamp holds before the cross-fade |
| `DSMotion.toastVisible` | 2.5 s | Toast auto-dismiss |
| `DSMotion.confetti` | 0.6 s | All-done confetti burst; not played under Reduce Motion |
| `DSMotion.stagger` | 0.02 s | Per-cell delay when a grid empties; each cell fades over `DSMotion.fade` |

### Curves and springs

| Name | Definition | Use |
|---|---|---|
| `DSMotion.enter` | `timingCurve(0.23, 1, 0.32, 1)` over `DSMotion.dur3` | Ease-out entry |
| `DSMotion.exit` | `timingCurve(0.32, 0, 0.67, 0)` over `DSMotion.dur1` | Fast ease-in exit |
| `DSMotion.standard` | `timingCurve(0.40, 0, 0.20, 1)` over `DSMotion.dur2` | Standard state change |
| `DSMotion.throwOut(duration:)` | `timingCurve(0.23, 1, 0.32, 1)` over a computed duration | The card throw |
| `DSMotion.snapBack` | `spring(response: 0.35, dampingFraction: 0.70)` | Card returns after an uncommitted drag: one small overshoot, settled in about 0.5 s |
| `DSMotion.land` | `spring(response: 0.45, dampingFraction: 0.78)` | Rewind: the card *lands*, it does not bounce |
| `DSMotion.stampPop` | `spring(response: 0.28, dampingFraction: 0.50)` | Stamp pop on a button-triggered verdict, `DSMotion.stampPopScale` (1.15) → 1 |
| `DSMotion.press` | `spring(response: 0.25, dampingFraction: 0.55)` | Button press, scale 0.90 → 1, via `DSPressStyle` |
| `DSMotion.stackSettle` | same as `DSMotion.snapBack` | Stack re-layout after a commit, so the deck breathes as one |
| `DSMotion.snapBackReduced` | `linear` over `DSMotion.dur1` | Reduce Motion substitute for `DSMotion.snapBack`; the card still has to return |
| `DSMotion.crossFade` | `linear` over `DSMotion.fade` | Reduce Motion substitute for the throw; the committed card still has to leave |

### The exit duration formula

```
exitDuration(velocity:) = clamp(DSSwipe.exitDistanceX / |velocity|, DSMotion.exitMin, DSMotion.exitMax)
```

A hard flick leaves in 0.18 s; a card dragged just past the threshold and released takes 0.32 s.
The point is that the exit continues the gesture's momentum instead of replacing it with a fixed
animation, which is what makes a throw feel thrown. With zero velocity the function returns
`DSMotion.exitMax`.

### The sector model

θ = `atan2(-dy, dx)`, with 0° pointing right. The plane is divided into four equal quadrants
(ADR-019):

| Sector | Range | Verdict |
|---|---|---|
| right | (−45°, 45°] | ARCHIVE |
| up | (45°, 135°] | FAVE |
| left | (135°, 225°] | TRASH |
| down | (225°, 315°] | dead zone, no verdict |

Four equal quadrants are one rule to learn rather than three exceptions. The sector is re-evaluated
on every `onChanged`; the commit happens only in `onEnded`. A drag that starts left and curls up
ends as FAVE, because the sector at release is the one that counts.

### Swipe tokens

| Token | Value | Rationale |
|---|---|---|
| `DSSwipe.commitDistance` | 120 | About a third of the card's width — far enough that it cannot be reached by an accidental brush, short enough for a thumb |
| `DSSwipe.commitVelocity` | 800 | A deliberate flick. Below this, distance decides |
| `DSSwipe.minTravelForVelocity` | 48 | Velocity alone cannot commit; this floor kills the fast tap that registers as a 4 pt drag |
| `DSSwipe.rotationDivisor` | 20 | Rotation = dx / 20, anchored at the card's bottom edge, so the card pivots like a paper card on a table |
| `DSSwipe.maxRotationDegrees` | 12 | Clamp. Past this the screenshot inside becomes hard to read |
| `DSSwipe.stampTiltDegrees` | 12 | Resting tilt of TRASH (+) and ARCHIVE (−); FAVE sits at 0°. Equal to the clamp, so a stamp on a fully tilted card reads as printed on it |
| `DSSwipe.stampRevealStart` | 20 | Below this the drag is still "I might" and shows nothing |
| `DSSwipe.stampRevealEnd` | 120 | Equal to `DSSwipe.commitDistance` on purpose: a fully opaque stamp *is* the "release will commit" signal |
| `DSSwipe.sectorHysteresisDegrees` | 6 | θ must cross this far into the neighbouring sector to switch, so a drag along a boundary does not flicker between two stamps |
| `DSSwipe.exitDistanceX` | 720 | Horizontal throw distance, far past any device edge |
| `DSSwipe.exitDistanceY` | 840 | Vertical throw distance |
| `DSSwipe.exitRotationDegrees` | 18 | Final rotation during the throw, past the drag clamp |
| `DSSwipe.downFollow` | 0.35 | The dead zone still follows the finger at 35 %, so "nothing happens" is felt as rubber band rather than as a frozen card |
| `DSSwipe.upScale` | 1.03 | The card lifts slightly at `DSSwipe.commitDistance` upward — the only verdict that grows |
| `DSSwipe.promoteAt` | 0.6 | At 60 % of the exit the side effect fires, the stack re-lays out and input is accepted again |

Stamp opacity is `clamp((d − DSSwipe.stampRevealStart) / (DSSwipe.stampRevealEnd − DSSwipe.stampRevealStart), 0, 1)`.

Gesture primitive: `DragGesture(minimumDistance: 10)` on the front card only. `translation` drives
what is drawn; `velocity` and `predictedEndTranslation` (iOS 17) drive the commit test.

### Stack geometry

`DSSize.stackDepth` is 3, so three cards are rendered. Card *n* behind the front card is offset by
`n × DSSize.stackOffsetY` and scaled by `1 − n × DSSize.stackScaleStep`:

| Position | Scale | Offset y |
|---|---|---|
| front | 1.00 | 0 |
| second | 0.94 | +14 |
| third | 0.88 | +28 |

During a drag the second card interpolates toward the front card's values by
`min(distance / DSSwipe.commitDistance, 1)`, so the deck starts opening before the commit rather
than snapping open after it. When the front card leaves, a fourth card fades in over
`DSMotion.fade`. Cards behind the front use `DSShadow.stack`.

### Rewind

One step only (ADR-008). The last card returns from its exit position with `DSMotion.land`, and its
stamp fades from 1 to 0 over `DSMotion.dur2`. The side effect is reversed to the *recorded prior
state*, not to a default: a favorite is un-set only if it was off before the swipe. History
survives navigating to Trash or Library within a session and is cleared on cold launch.

### Reduce Motion variants

| Behaviour | Normal | Reduce Motion |
|---|---|---|
| Drag translation | 1:1 with the finger | unchanged — direct manipulation is not decoration |
| Card rotation | dx / `DSSwipe.rotationDivisor`, clamped | removed |
| Stack parallax | second card interpolates | removed, cards hold their positions |
| Stamp opacity ramp | `DSSwipe.stampRevealStart` → `DSSwipe.stampRevealEnd` | unchanged — it is feedback, not motion |
| Commit | throw over `DSMotion.exitDuration(velocity:)` | substituted: stamp holds for `DSMotion.stampHoldReduced`, then `DSMotion.crossFade` |
| Snap-back | `DSMotion.snapBack` spring | substituted: `DSMotion.snapBackReduced` |
| All-done celebration | `DSMotion.confetti` burst | not shown |
| Press | `DSMotion.press` spring | the pressed scale still applies, the spring does not |

The rule behind the table: Reduce Motion removes *interpretive* movement (rotation, parallax,
overshoot, celebration) and keeps *informational* movement (the card under the finger, the stamp
ramp, the pressed state). "Removes" is not the gate's only move. Where something still has to
happen — an uncommitted card has to come back, a committed card has to leave — the gate substitutes
rather than deletes, through `gated(_:reduce:reduced:)`. The two rows marked *substituted* above are
those cases, and each names the token that replaces the spring or the throw.

**The guide runs both substitutions rather than describing them.** `design-system.html` still cuts
animation and transition durations to `.01ms` under `prefers-reduced-motion`, but its blanket rule
now excludes the deck, so the two substituted rows actually execute there. The exclusion is written
`*:not(:where(.deck__card, .deck__card *))` and is repeated for the element and for its `::before`
and `::after`; on 2026-09-24
`grep -c ':not(:where(.deck__card, .deck__card \*))' design-system.html` returned 3, and
`grep -c 'prefers-reduced-motion: reduce' design-system.html` returned 2, one for that `@media` block
and one for the `matchMedia` call the swipe demo reads. Measured in a browser under emulated
`prefers-reduced-motion`: the snap-back runs 0.12 s linear, which is `DSMotion.snapBackReduced` at
`--motion-dur1`, and a commit holds the stamp and then cross-fades, while a chrome button outside the
deck measures 1e-05s. `revert-layer` does not work for this. With no cascade layers declared, it
rolls the property back to the UA value, 0s, which is the same instant cut the exclusion exists to
avoid.

---

## 7. Haptics

One choke point, `.dsHaptic(_:trigger:)`. Nothing calls a feedback generator directly. The rule,
inherited from the previous app: a verdict is an `.impact`, a completed success is `.success`, a
destructive confirmation is `.warning` (ADR-007).

Impact **weight encodes direction**, so eyes-off swiping still confirms which verdict landed.

| Event | `DSHaptic` case | Feedback | When |
|---|---|---|---|
| Drag crosses the commit threshold | `.thresholdArmed` | `.selection` | Rising edge only — once per drag, not on every frame past 120 pt |
| Swipe left committed | `.trash` | `.impact(weight: .heavy)` | On commit, a thud into the bin |
| Swipe right committed | `.archive` | `.impact(weight: .medium)` | On commit |
| Swipe up committed | `.fave` | `.impact(weight: .light)` ×2 | On commit, a heartbeat |
| Rewind | `.rewind` | `.impact(weight: .light)` | When the card starts coming back |
| Restore from Trash | `.restore` | `.success` | After the asset returns to the queue |
| "Delete permanently" tapped | `.purgeArmed` | `.warning` | Fired just before the iOS dialog is presented |
| Permanent deletion finished | `.purgeDone` | `.success` | After `deleteAssets` reports success |
| Queue finished | `.queueDone` | `.success` | When the last card leaves |
| Photo access granted | `.permissionGranted` | `.success` | After the system dialog returns an authorized status |
| Segment switched | `.segment` | `.selection` | Favorites ↔ Archive |
| Failure | `.error` | `.error` | A delete or a move failed |

Silent by design: snap-back after an uncommitted drag, and every drag in the down dead zone.
Nothing happened, so nothing is reported.

### The double pulse

`DSHaptic.pulses` is 2 for `.fave` and 1 for everything else, with
`DSHaptic.pulseGapMilliseconds` = 90. The modifier implements it by holding a second `echo`
trigger: on a change it fires the primary feedback, then sleeps 90 ms on the main actor and bumps
`echo`, which fires the same feedback again. Two light taps 90 ms apart are distinguishable from
one medium tap, which is what makes FAVE identifiable without looking.

### No sound

There is no sound in v1 (ADR-012). v1 has no settings screen, so a sound that cannot be turned off
would be a defect rather than a feature. Haptics carry the game feel. If sound is added later it
will be short custom samples on the `.ambient` category, opt-in.

---

## 8. Icons

Bold **solid** glyphs from the Noun Project, exported as template PDFs into the asset catalog
(ADR-017). The free plan is CC BY, so every shipped icon needs a credit line.

### Inventory

Twelve glyphs. `fallbackSymbol` is development scaffolding: until the asset is dropped into the
catalog, `DSIconRef.image` returns the SF Symbol so the app runs. A shipping build has no
fallbacks left.

| `DSIcon` | `asset` | `fallbackSymbol` | `query` | Where used |
|---|---|---|---|---|
| `trash` | `icon-trash` | `trash.fill` | trash solid | TRASH stamp, Trash verdict button, Trash header button, viewer action |
| `archive` | `icon-archive` | `archivebox.fill` | archive box solid | ARCHIVE stamp, Archive verdict button, Library move action |
| `fave` | `icon-heart` | `heart.fill` | heart solid | FAVE stamp, Fave verdict button, Library move action |
| `rewind` | `icon-rewind` | `arrow.uturn.backward` | undo arrow bold | Rewind button in the verdict row |
| `restore` | `icon-restore` | `arrow.counterclockwise` | restore arrow bold | Trash viewer and context menu |
| `library` | `icon-library` | `photo.on.rectangle.angled` | photo stack solid | Library button in the Review header |
| `settings` | `icon-settings` | `gear` | gear solid | "Open Settings" on the denied permission screen |
| `close` | `icon-close` | `xmark` | close x bold | Viewer dismiss, sheet dismiss |
| `warning` | `icon-warning` | `exclamationmark.triangle.fill` | warning triangle solid | Inline error lines, the purge-all sheet |
| `check` | `icon-check` | `checkmark.circle.fill` | check circle solid | Completed directions in the swipe legend |
| `chevron` | `icon-chevron` | `chevron.right` | chevron right bold | Row disclosure, credits screen |
| `photoAccess` | `icon-photos` | `photo.badge.checkmark.fill` | photo permission solid | Permission screen, limited-access interstitial |

`DSIcon.all` holds the same twelve in order and is what the credits screen and the guide iterate.

### Style rules

- **Bold solid, never outline.** An outline glyph disappears on a busy screenshot and reads thin
  next to Forager Bold Overlap.
- **Template rendering.** Assets are exported as template PDFs and drawn with
  `.renderingMode(.template)`, so an icon has no color of its own.
- **Color is inherited.** Always `foregroundStyle`; the glyph takes `ink`, `ink2`, `onAccent`, or a
  verdict's `on`, depending on what it sits on.
- **No tiles.** Never a filled box, circle or rounded square *behind* a glyph as decoration. The
  three verdict buttons are circles because they are buttons, not because the glyph needs a
  container.
- **Three sizes only.** `DSSize.iconVerdict` inside a verdict button, `DSSize.iconChrome` in
  headers and toolbars, `DSSize.iconInline` in a line of text; the stamp glyph is
  `DSSize.stampIcon`.

### Credits

CC BY requires attribution for each icon. `DSIconCredit.line` formats one entry as:

```
<title> by <author> from Noun Project
```

The title and author are exactly what the Noun Project download dialog shows. `DSIconCredit` also
stores the source `url` so a reader can find the original.

### `DSIconCredits` workflow

1. Search thenounproject.com with the `query` from the inventory table.
2. Download the bold solid SVG, convert to PDF, and add it to the asset catalog under the `asset`
   name from the table.
3. Add one `DSIconCredit(asset:title:author:url:)` to `DSIconCredits.entries` in the same commit as
   the asset. An asset without a credit line is a license violation, so the two changes belong in
   one commit.
4. The credits screen renders `DSIconCredits.entries`. `DSIconCredits.hasEntries` is false while
   the array is empty, and the screen then says that no third-party icons ship yet — which is true
   today.

The credits screen is reachable from the onboarding footer. It is a list of `subhead` title lines
with `caption` author lines, each row opening the stored `url`.

---

## 9. Illustration

There are no illustration assets. Every figure in the app is typeset (ADR-016), which is why the
app has no image pipeline, no export step, and no light/dark artwork problem.

### Typographic faces

A face is **one** glyph borrowed from a world script, framed by round parentheses, set in
`DSTextRole.display` on a color block, centered: `(ᐛ)`. The parentheses are the head; the glyph
is the eyes and the mouth at once, so a face is one line, not two. Seven blocks, seven scripts, no
glyph used twice. Only the brackets come from the display face; each centre glyph is drawn by
whichever system font carries its script, and the weight contrast between a bold Latin bracket and a
lighter non-Latin letter is the intended look. It is also why a face never carries information:
every face is `accessibilityHidden` and the block's headline says what happened.

`DSFace` exposes `glyph`, `origin` (the Unicode name, printed below so nobody has to guess), the
static brackets `DSFace.open` and `DSFace.close` — round, never square, because a head is a head —
and `text`, the whole face as one string for a preview or a snapshot test.

| `DSFace` | Glyph | `DSFace.origin` | Script | Mood |
|---|---|---|---|---|
| `eager` | ᐛ | U+141B CANADIAN SYLLABICS NASKAPI WAA | Canadian syllabics (Naskapi) | eager, a ready lopsided grin |
| `delighted` | ஶ | U+0BB6 TAMIL LETTER SHA | Tamil | delighted, wide open |
| `breezy` | ツ | U+30C4 KATAKANA LETTER TU | Katakana | breezy, a shrug |
| `soft` | ω | U+03C9 GREEK SMALL LETTER OMEGA | Greek | soft, waiting to be given something |
| `blank` | ఠ | U+0C20 TELUGU LETTER TTHA | Telugu | blank, perfectly and roundly empty |
| `tearful` | ಥ | U+0CA5 KANNADA LETTER THA | Kannada | tearful, downcast |
| `quizzical` | ѹ | U+0479 CYRILLIC SMALL LETTER UK | Cyrillic | quizzical, head tilted, making do |

### Color blocks

`DSBlock` fixes which screen gets which fill, which ink and which face. The mapping is a token, not
a per-screen choice, so the same state always looks the same.

| `DSBlock` | Screen | Fill | Ink | `ctaFill` | `ctaLabel` | `focusRing` | Face |
|---|---|---|---|---|---|---|---|
| `onboarding` | Permission, first run | `trash.main` | `ink` | `ink` | `onAccent` | `ink` | `eager` |
| `allDone` | Review, queue finished | `lime` | `ink` | `ink` | `onAccent` | `ink` | `delighted` |
| `trashEmpty` | Trash, empty | `mint` | `ink` | `ink` | `onAccent` | `ink` | `breezy` |
| `favoritesEmpty` | Library, Favorites empty | `pink` | `ink` | `ink` | `onAccent` | `ink` | `soft` |
| `archiveEmpty` | Library, Archive empty | `lavender` | `ink` | `ink` | `onAccent` | `ink` | `blank` |
| `denied` | Permission, denied | `violet` | `onAccent` | `onAccent` | `accent` | `onAccent` | `tearful` |
| `limited` | Permission, limited interstitial | `fave.soft` | `ink` | `ink` | `onAccent` | `ink` | `quizzical` |

Seven blocks, seven faces, one each: no face is used twice, which is why `DSFace` has exactly as
many cases as `DSBlock`.

`DSBlock.ink` is `ink` for every block except `denied`, which takes `onAccent` — white on violet
measures 6.95:1, navy on violet would not clear 4.5:1.

The last three columns are derived, not chosen per screen. `DSBlock.ctaFill` returns the block's own
`ink`, `DSBlock.ctaLabel` returns that ink's counterpart (`onAccent` on the six blocks whose ink is
`ink`, `accent` on `denied`, the one block whose ink is `onAccent`), and `DSBlock.focusRing` returns
the block's `ink` at full strength. So a block has one ink pair and the pill inverts it; there is no
per-screen decision left to make. The measurements are in [Rules](#rules) below.

### Rules

- A block is full-bleed or it does not exist. No block as a card, a banner or a panel.
- Blocks appear on onboarding and on empty states only. A populated screen is white.
- The expressive colors never carry verdict meaning, and verdict colors never serve as blocks, with
  two deliberate exceptions under ADR-016. `onboarding` is `trash.main` because the reference hero is
  tomato and onboarding happens before the user has learned that tomato means trash. `limited` is
  `fave.soft` because a pale tint reads as a notice rather than as a state, and the interstitial is a
  notice. Two exceptions, both named here and in [§1 Expressive palette](#expressive-palette); there
  is no third. `DSBlock`'s own header comment used to state the first half of that rule as absolute,
  claiming a verdict colour is never used as a block. It now names both exceptions and points at
  ADR-016, so the Swift file and this section no longer disagree.
- **The CTA pill inverts the block's ink pair.** `DSBlock.ctaFill` is the block's own `ink` and
  `DSBlock.ctaLabel` is that ink's counterpart: `onAccent` on the six blocks inked `ink`, `accent`
  on `denied`, whose ink is `onAccent`. It is not a choice. Filled with the block's ink the pill
  measures 4.61 against its block at worst (`ink` on `trash.main`) and 14.01 at best (`ink` on
  `fave.soft`), and its label measures 16.16 on every block, in both directions.
- **A block carries one filled action, and it is that pill.** A second action on the same block is
  bare text in the block's ink, with no fill and no outline. That is what "nothing else on a block is
  filled" means, and it is a measurement rather than a preference. A filled secondary is a shape, so
  it would owe its own 3:1 row against all seven block fills, and the neutral fill it would reach
  for is `surfaceRaised`, which measures 2.16 against `lavender` (the same `contrast()` in
  `scripts/ds_tokens.py`, run on the two OKLCH values; there is no `PAIRS` row for it because the
  system has no such control). With no fill there is no shape to measure, only the label, and the
  label is the block's ink on the block, which is the copy row the block already clears at the
  stricter 4.5 bar. In the guide the pair is `.btn--onblock` beside `.btn--onblock-text`. In the app
  it is `"\(Brand.name) these 14"` beside `"Pick more"` on `DSBlock.limited`, and `"Open Settings"`
  beside `"Not now"` on `DSBlock.denied` ([§11.1](#111-permission), [§10 Buttons](#buttons)).
- **The focus ring on a block is `DSBlock.focusRing`, the block's ink at full strength, not
  `DSColor.focus`.** `focus` is `ink` at 60 %, tuned for the neutral surfaces; composited over a
  saturated block it measures 2.65 on `trash.main`, 2.92 on `lavender` and 1.71 on `violet`, all
  under the 3:1 non-text bar. At full strength the ring is the same pair as the block's copy, which
  the table already clears at 4.5. The stroke width stays `DSSize.focusRing` 3
  ([§5 Focus ring](#focus-ring)).
- Copy on a block is `ink` at `body` or larger. The binding row is
  `text · destructive button label (16 pt bold) and onboarding copy on tomato`: on tomato, `ink`
  measures 4.61:1 and clears 4.5:1 by 0.11.

**Correction, 2026-09-24.** This section used to say "on a block the CTA is a navy pill (`accent`)
or a white pill (`surface` fill, `ink` label)". That free choice was the defect. Measured with
`scripts/ds_tokens.py`, a white pill is invisible as a shape on five of the seven blocks: 1.15
against `lime`, 1.15 against `fave.soft`, 1.53 against `pink`, 1.79 against `mint`, 2.61 against
`lavender`. A navy pill is invisible on the sixth, 2.33 against `violet`. Only `trash.main` would
have survived a white pill, at 3.51. A shape that cannot reach 3:1 against what it sits on is not a
button, whatever its label measures, and the old wording let a designer pick that shape on five
screens out of seven. `DSIllustration.swift` now derives the pill from the block, so the choice no
longer exists. The same reasoning retired `DSColor.focus` on blocks.

Neither change needed a new contrast row for the pill against its block or for the ring against its
block. Each of those is the block's own ink against the block, which is the pair the block's copy row
already carries at the 4.5 text bar rather than at 3: `ink` on `trash.main`, on `mint`, on `lime`, on
`pink` and on `lavender`, `onAccent` on `violet`, and `ink` on `fave.soft` for `limited`. Seven
blocks, seven rows that already existed. The two rows that were added are for the pill *label*,
`onAccent` on `ink` and `accent` on `onAccent`, which is why the table now ends at 43 pairs instead
of 41.

---

## 10. Components

Components are built from tokens, screens are built from components, and nothing skips a level.
Each entry gives anatomy, the tokens it consumes, its states, and its accessibility contract.

### ScreenshotCard

- **Anatomy.** A `surface` rectangle at `DSRadius.xl` holding the screenshot inside a
  `DSSize.cardInset` letterbox, with a date chip bottom-left and at most one stamp overlaid. Width is
  the screen width minus 2 × `DSGrid.mobileMargin`; height is the space above the verdict row minus
  `DSSpace.s5`. The screenshot is `.fit`, never `.fill` — cropping hides the part being judged.
- **Tokens.** `surface`, `DSRadius.xl`, `DSSize.cardInset`, `DSShadow.floating` in front or
  `DSShadow.stack` behind, `chip` at `DSRadius.xs` with `DSTextRole.caption`.
- **States.** `top` · `dragging` · `thrown` left/right/up · `behind-1` · `behind-2` ·
  `loading` (shimmer) · `unloadable`.
- **Accessibility.** The front card is one element labelled
  `"Screenshot, Sep 21, 2:14 PM, 1.2 MB, 12 of 340"`; cards behind it and every stamp are
  `accessibilityHidden`. Verdicts are custom actions, ordered Trash, Archive, Favorite, Rewind last.

### CardStack

- **Anatomy.** `DSSize.stackDepth` cards front-to-back in a `ZStack`; only the front card takes a
  gesture. On commit the stack re-lays out at `DSSwipe.promoteAt` of the exit with
  `DSMotion.stackSettle`, and a new back card fades in over `DSMotion.fade`.
- **Tokens.** `DSSize.stackOffsetY`, `DSSize.stackScaleStep`, `DSSize.stackDepth`,
  `DSShadow.stack`, `DSMotion.stackSettle`, `DSMotion.fade`, every `DSSwipe` token.
- **States.** `loading` · `populated` · `last` (nothing behind) · `done`.
- **Accessibility.** A container with no label of its own; the front card carries everything.

### VerdictStamp

- **Anatomy.** A pill holding the verdict glyph at `DSSize.stampIcon` and the verdict word in
  `DSTextRole.stamp`, uppercase. TRASH sits top-right at +`DSSwipe.stampTiltDegrees`, ARCHIVE top-left at
  −`DSSwipe.stampTiltDegrees`, FAVE at 0° with its centre `DSSize.stampFaveRaise` of the card height above the middle, each inset from the card edge by `DSSpace.s5`. The fill is
  solid `main`, not an outline: screenshots are usually white and an outline vanishes on one.
- **Tokens.** `DSRadius.pill`, a verdict's `main` with its `on`, `DSTextRole.stamp`
  (`DSTextRole.stampBaseSize` 32, capped at `DSTextRole.stampMaxSize` 44), `DSShadow.floating`,
  `DSSwipe.stampRevealStart`, `DSSwipe.stampRevealEnd`, `DSMotion.stampPop`, `DSMotion.dur2`.
- **States.** `hidden` below `DSSwipe.stampRevealStart` · `revealing` as opacity ramps with distance ·
  `committed` at full opacity, which is also the signal that releasing will commit.
- **Accessibility.** `accessibilityHidden`. The verdict reaches VoiceOver as the custom action the
  user invoked and as the announcement after it.

### VerdictButtonRow and RewindButton

- **Anatomy.** A docked row in a bottom `safeAreaInset`: Rewind pinned to the leading edge, then three
  circles centered as a group — Trash, Fave, Archive, left to right — so the row is a map of the three
  directions. Each circle carries a `DSTextRole.buttonCaption` label. The circles are solid `main`
  with the `on` glyph; a tinted circle would put a low-contrast glyph on a pale fill and read as
  disabled. A tap runs the same pipeline as a swipe: the stamp pops with `DSMotion.stampPop`, the card
  exits over `DSMotion.buttonFlick` with rotation clamped to `DSSwipe.maxRotationDegrees`, the same
  haptic fires. One code path per verdict, not two.
- **Tokens.** `DSSize.verdictButton`, `DSSize.faveButton`, `DSSize.faveButtonRaise`,
  `DSSize.rewindButton`, `DSSize.iconVerdict`, `DSRadius.pill`, `DSTextRole.buttonCaption`,
  `DSShadow.floating`, `DSPressStyle` with `DSMotion.press`, `DSSpace.s5` between circles,
  `DSGrid.mobileMargin` for the Rewind inset, `DSLayer.sticky`.
- **States.** `enabled` · `pressed` (scale 0.90) · `disabled` at `DSOpacity.disabled` (0.45) — Rewind with no
  history, or any button while a card is in flight.
- **Accessibility.** Every button is at least `DSSize.tapMin`. Labels are "Trash", "Archive",
  "Favorite", "Rewind last". A disabled button keeps its label and gains the disabled trait rather
  than disappearing.

### ProgressCounter

- **Anatomy.** One line, leading in the Review header: position, slash, total, with
  `.contentTransition(.numericText())` so the changed digit rolls.
- **Tokens.** `DSTextRole.counter` (Pretendard Bold 22, `monospacedDigit()`), `ink`.
- **States.** `"12 / 340"` · `done`, replaced by the all-done block · `loading`, `"— / —"`.
- **Accessibility.** Read as "12 of 340", not "12 slash 340", and repeated at the end of the card's
  label so position is available without leaving the card.

### ThumbnailCell

- **Anatomy.** A square, center-cropped thumbnail. Variants `.trash` and `.library` are the same cell
  with a different context menu and a different viewer action set.
- **Tokens.** `DSRadius.xs`, `DSSize.gridColumns`, `DSSize.thumbnailGutter`, `surfaceRaised` while
  loading, `DSMotion.fade` on removal.
- **States.** `default` · `pressed` · `removing`, fading over `DSMotion.fade` and staggered by `DSMotion.stagger` across the
  grid.
- **Accessibility.** Labelled with the asset's date and size; context-menu actions are also exposed as
  custom actions, so they are reachable without a long press.

### AssetViewer

- **Anatomy.** Full-screen black with the asset fitted, a top bar carrying `DSIcon.close`, and a
  bottom action bar. Pinch to zoom, double-tap to 2×, swipe down to dismiss. Two action sets only:
  from Trash, Restore and Delete permanently; from Library, Move to Archive / Move to Favorites and
  Trash.
- **Tokens.** `onImage`, `DSSize.iconChrome`, `DSTextRole.label`, `DSRadius.pill`, `DSMotion.dur3`,
  `DSLayer.modal`.
- **States.** `loading` · `presented` · `zoomed` · `dismissing`.
- **Accessibility.** The image carries its cell's label; action buttons are `DSSize.tapMin` or larger;
  "Delete permanently" carries the destructive trait.

### PurgeAllSheet

- **Anatomy.** A sheet at `DSRadius.xl` over a `scrim`: title, body, destructive button, cancel
  button. It exists for the "all" case only (ADR-009). Confirming dismisses the sheet, fires
  `DSHaptic.purgeArmed`, and only then calls `deleteAssets`, which presents the iOS dialog — the sheet
  must be gone first or two confirmations stack.
- **Tokens.** `surface`, `DSRadius.xl`, `scrim`, `DSShadow.floating`, `DSLayer.modal`,
  `DSTextRole.subhead`, `DSTextRole.body`, `DSTextRole.label`, `trash.main` with `ink` for the
  destructive button, `surfaceRaised` with `ink` for cancel, `DSSpace.s5` padding, `DSMotion.dur3`.
- **States.** `default` · `pending`, progress in the button and both buttons disabled · `error`, an
  inline line with `DSIcon.warning` and the sheet stays open.
- **Accessibility.** The destructive label contains the count, so it is unambiguous out of context.
  Focus moves to the title on present and back to the docked button on dismiss.

### SegmentedControl

- **Anatomy.** Two segments in a `surfaceRaised` track with a `surface` thumb inset by `DSSpace.s1`,
  so by the nesting rule the thumb's radius is one step below the track's.
- **Tokens.** `surfaceRaised`, `surface`, `DSRadius.md`, `DSTextRole.label`, `ink` selected and `ink2`
  unselected, `DSMotion.standard`, `DSHaptic.segment`.
- **States.** Favorites selected · Archive selected. An empty side is not disabled — it shows its
  empty state.
- **Accessibility.** An adjustable, tab-like element; each segment's label carries its count, for
  example "Favorites, 12".

### EmptyState

- **Anatomy.** A full-bleed `DSBlock`: face in `DSTextRole.display`, headline in
  `DSTextRole.headline`, optional body in `DSTextRole.body`, optional CTA pill in `DSBlock.ctaFill`
  with a `DSBlock.ctaLabel` label, and at most one further action, which is bare text in the block's
  `ink` rather than a second pill ([§10 Buttons](#buttons)).
- **Tokens.** The block's `fill`, `ink`, `ctaFill`, `ctaLabel` and `focusRing` from `DSBlock`,
  `DSTextRole.display` / `headline` / `body` / `label`, `DSRadius.pill`, `DSSpace.s5`, `DSSpace.s7`.
- **States.** Five, and no others: `noScreenshots` and `allDone` on Review, `trashEmpty` on Trash,
  `noFavorites` and `noArchived` on Library. Four name their block directly: `allDone` →
  `DSBlock.allDone`, `trashEmpty` → `DSBlock.trashEmpty`, `noFavorites` → `DSBlock.favoritesEmpty`,
  `noArchived` → `DSBlock.archiveEmpty`. `noScreenshots` has no `DSBlock` case of its own; see
  [§15](#15-open-questions) item 5. Losing authorization is not an `EmptyState`: Review leaves the
  queue for the Permission screen's denied block ([§11.2](#112-review)).
- **Accessibility.** The face is hidden; the headline is the element; the CTA is a button with its own
  label.

### PermissionScreen, SwipeLegend, DemoStack

- **Anatomy.** The top 55 % is `DemoStack` — three bundled sample screenshots looping through the
  three verdicts at 1.2 s each, driven by the real gesture code with synthetic input so the demo
  cannot drift from the product. The user can interrupt it and swipe for real; a completed direction
  gets a `DSIcon.check` in the legend. Under Reduce Motion the stack becomes three static panels.
  Below it sit the headline, `SwipeLegend`, the CTA, and a footer link to the credits screen.
- **SwipeLegend.** Three rows: Left / TRASH / the app's Trash until you empty it · Right / ARCHIVE /
  the `Brand.archiveAlbumTitle` album in Photos · Up / FAVE / your Photos favorites.
- **Tokens.** `DSBlock.onboarding` (`trash.main` fill, `ink` ink, so `ctaFill` is `ink` and
  `ctaLabel` is `onAccent`), `DSTextRole.headline`, `DSTextRole.body`, `DSTextRole.label`,
  `DSRadius.pill`, `DSSize.iconInline`, `DSMotion.fade`, every `DSSwipe` token.
- **States.** `notDetermined` · `limited` · `denied` · `authorized`.
- **Accessibility.** The demo is `accessibilityHidden` and the legend carries the same information as
  text. The CTA is the first focusable element after the headline.

### Buttons

Five kinds, no more, and only four of them carry a fill. All five use `DSPressStyle`, pad by
`DSSpace.s3` vertically and `DSSpace.s5` horizontally, and are at least `DSSize.tapMin` tall. Only
primary and destructive take `DSShadow.floating`, and only when docked over content.

| Kind | Fill | Label | Radius | Used for |
|---|---|---|---|---|
| primary | `accent` | `onAccent`, `DSTextRole.label` | `DSRadius.pill` | The one main action on a white screen |
| secondary | `surfaceRaised` | `ink`, `DSTextRole.labelSmall` | `DSRadius.md` | The second action on a white surface: "Keep them", Cancel |
| destructive | `trash.main` | `ink`, `DSTextRole.label` | `DSRadius.pill` | "Delete all permanently", "Delete N permanently" |
| block CTA | `DSBlock.ctaFill`, the block's own ink | `DSBlock.ctaLabel`, `DSTextRole.label` | `DSRadius.pill` | The one filled action on a full-bleed color block |
| block text action | none | the block's `ink`, `DSTextRole.label` | `DSRadius.pill`, for the focus ring only | The second action on a block: "Pick more", "Not now" |

The fifth kind is a consequence of the fourth. A block carries one filled action, so a second action
on a block cannot be a secondary pill: `surfaceRaised` measures 2.16 against `lavender`, and a fill
that owes 3:1 against seven different blocks buys nothing the label does not already buy. Bare text
in the block's ink has no shape to measure, and its label is the pair the block's copy row clears at
4.5. It keeps `DSRadius.pill` even with nothing to fill, because the focus ring still needs a shape
to follow, and in the guide it inherits that radius from the base `.btn` rule. That is why "Pick more"
and "Not now" are no longer listed on the secondary row: both sit on blocks, and secondary's
`surfaceRaised` is a neutral fill that works only on a white surface. See [§9 Rules](#rules).

The destructive label is `ink`, not `trash.on`. `DSTextRole.label` is 16 pt bold, below WCAG's 19 pt
bold large-text floor, so it owes the full 4.5:1: navy on tomato measures 4.61:1, white on tomato
only 3.51:1. White on tomato stays legal for the 32 pt stamp word and for the verdict glyphs, which
are large text and non-text respectively, and for nothing at label size.

The fourth kind used to be listed here as a "white pill", `surface` fill with an `ink` label,
described as "the CTA on a color block, where navy on color would be heavy". That is the wording
[§9 Rules](#rules) corrects: a white pill measures 1.15 against `lime` and `fave.soft`, 1.53 against
`pink`, 1.79 against `mint` and 2.61 against `lavender`, so on five of the seven blocks it is not a
visible shape at all. The kind is now `DSBlock.ctaFill` with `DSBlock.ctaLabel`, derived from the
block. On the six blocks inked `ink` it renders navy with a white label, which is the primary button
by another route; on `denied` it inverts to white with a navy `accent` label, because that block's
ink is `onAccent`. It is kept as its own kind because the fill comes from the block, not from
`accent`.

The guide draws both directions rather than describing them: `.btn--onblock` is the navy pill with a
white label, `.btn--onblock-inverted` is the white pill with a navy label, and the two demo blocks it
sits them on are `lavender` and `violet`. Those are the `ink` on `lavender` row at 6.18 and the
`onAccent` on `violet` row at 6.95, with the label at 16.16 in both directions. A browser's own
colour picker reports 6.15, 6.97 and 16.14 for the same three pairs; that gap is rounding in the
measuring tool, not a different colour, and the generated table is the number to quote.

- **States.** `default` · `pressed` · `disabled` at `DSOpacity.disabled` (0.45) · `loading`, label replaced by a
  progress view at the same size.
- **Accessibility.** The destructive kind carries the destructive trait and always includes a count in
  its label.

### Toast

- **Anatomy.** A capsule anchored at the top, one line, no action button. Undo lives on exactly one
  control, the rewind button; a second undo affordance that appears for 2.5 s and then vanishes would
  be a race, not a safety net. Used for `"Not deleted"` after the system dialog is cancelled, and for
  failures.
- **Tokens.** `toast` with `onToast`, `DSTextRole.labelSmall`, `DSRadius.pill`, `DSShadow.floating`,
  `DSLayer.toast`, `DSMotion.toastVisible`, `DSMotion.enter`, `DSMotion.exit`.
- **States.** `enter` · `visible` for 2.5 s · `exit`.
- **Accessibility.** Posted as an announcement. It never takes focus — taking focus mid-task would
  interrupt the user's place in the queue.

### Credits screen

- **Anatomy.** A pushed screen with a `DSTextRole.title` header and one row per
  `DSIconCredits.entries` element: the credit line in `DSTextRole.body`, `DSIcon.chevron` trailing,
  the stored URL opened by tapping the row.
- **Tokens.** `canvas`, `DSTextRole.title` / `body` / `caption`, `DSSize.iconInline`, `DSSpace.s4`,
  `ink`, `ink2`.
- **States.** `populated` · `empty` — when `DSIconCredits.hasEntries` is false the screen states that
  no third-party icons ship yet, which is the current state.
- **Accessibility.** Each row is one element with a link trait and the full credit line as its label.

---

## 11. Screens

Four screens (ADR-011). Review is the root; Trash and Library are pushed from icon buttons in the
Review header. There is no tab bar: it would take 83 pt away from the card and imply three equal
destinations, and the card is the product.

Copy strings that contain the product name are written as `Brand.name` interpolations, which is how
they appear in code (ADR-002).

### 11.1 Permission

Two steps, modelled on the FaceApp reference below: the app explains itself first, the system
dialog second. Permission is requested on tap, never on launch (ADR-010).

| Region | Component | States | Copy |
|---|---|---|---|
| Top 55 % | `DemoStack` | looping · interrupted · reduced (three static panels) | — |
| Headline | `DSTextRole.headline` on `DSBlock.onboarding` | — | `"\(Brand.name) your screenshots."` |
| Legend | `SwipeLegend` | three rows, each unchecked or checked | Left → TRASH · Right → ARCHIVE · Up → FAVE |
| CTA | block CTA on `DSBlock.onboarding` | default · pressed | `"Show me the screenshots"` |
| Footer | link | — | credits screen |

On tap the app calls `requestAuthorization(for: .readWrite)`. Three outcomes:

| Outcome | Block | Copy | Actions |
|---|---|---|---|
| Full | — | — | Go straight to Review; `DSHaptic.permissionGranted` |
| Limited | `DSBlock.limited` (`fave.soft`) | `"You picked 14 screenshots. \(Brand.name) only sees those."` | `"\(Brand.name) these 14"` is the filled block CTA · `"Pick more"` is the block text action (`presentLimitedLibraryPicker`) |
| Denied | `DSBlock.denied` (`violet`, white ink) | `"\(Brand.name) can't see your screenshots yet."` | `"Open Settings"` is the filled block CTA, white on violet · `"Not now"` is the block text action |

The denied state re-checks authorization whenever `scenePhase` becomes `.active`, so a user who
changes the setting and comes back lands in Review without tapping anything.

**References.** Three screenshots from the Lazyweb library informed this screen (`docs/references.md`;
signed URLs, valid about a year from 2026-09-22). A search for swipe-to-triage card decks and photo
cleaners returned nothing usable — the library's coverage there is weak — so the permission screen
is the only place external references are cited.

- Google Photos — the iOS system dialog with the reason line and Select Photos / Allow All /
  Don't Allow. Source of: the wording pattern for the reason line.
  [screenshot](https://zlfyzdmohcskkucuunmk.supabase.co/storage/v1/render/image/sign/screenshots/uploaded_google_photos/main_tabs/compare/2026-05-28/1779943488149_00_Google_Photos-20260528-044447-01.png?token=eyJraWQiOiI1NTU0MmU4OC1mNWRkLTQxMDEtOWZkYy0yODFiMzM3NmYyOTIiLCJhbGciOiJIUzI1NiJ9.eyJ0cmFuc2Zvcm1hdGlvbnMiOiJ3aWR0aDo3NjgscmVzaXplOmNvbnRhaW4scXVhbGl0eTo3MCIsInVybCI6InNjcmVlbnNob3RzL3VwbG9hZGVkX2dvb2dsZV9waG90b3MvbWFpbl90YWJzL2NvbXBhcmUvMjAyNi0wNS0yOC8xNzc5OTQzNDg4MTQ5XzAwX0dvb2dsZV9QaG90b3MtMjAyNjA1MjgtMDQ0NDQ3LTAxLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMTc0MzMsImV4cCI6MTgyMTY1MzQzM30.HiUhKqOQqurg1SQ60IxyzPcJjOH9Sv6fJNe_Ziv_fSE)
- Gio (Photo & Video) — the system prompt previewing a thumbnail grid and a count, with Limit
  Access / Allow Full Access / Don't Allow. Source of: showing the user the count of what they
  picked in the limited interstitial.
  [screenshot](https://zlfyzdmohcskkucuunmk.supabase.co/storage/v1/render/image/sign/screenshots/uploaded_gio/compare/2026-02-10/1771028039306_t__-_19300.PNG?token=eyJraWQiOiI1NTU0MmU4OC1mNWRkLTQxMDEtOWZkYy0yODFiMzM3NmYyOTIiLCJhbGciOiJIUzI1NiJ9.eyJ0cmFuc2Zvcm1hdGlvbnMiOiJ3aWR0aDo3NjgscmVzaXplOmNvbnRhaW4scXVhbGl0eTo3MCIsInVybCI6InNjcmVlbnNob3RzL3VwbG9hZGVkX2dpby9jb21wYXJlLzIwMjYtMDItMTAvMTc3MTAyODAzOTMwNl90X18tXzE5MzAwLlBORyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMTc0MTEsImV4cCI6MTgyMTY1MzQxMX0.cohEl-KQQo8DXPH7Hn43henpFUYgRfFj7mh5cKCz1NE)
- FaceApp — the app's own explanation screen shown *before* the system dialog, with a Continue
  button. Source of: the two-step structure of this screen.
  [screenshot](https://zlfyzdmohcskkucuunmk.supabase.co/storage/v1/render/image/sign/screenshots/photos2_faceapp/compare/2024-11-10-22-22-18-.png?token=eyJraWQiOiI1NTU0MmU4OC1mNWRkLTQxMDEtOWZkYy0yODFiMzM3NmYyOTIiLCJhbGciOiJIUzI1NiJ9.eyJ0cmFuc2Zvcm1hdGlvbnMiOiJ3aWR0aDo3NjgscmVzaXplOmNvbnRhaW4scXVhbGl0eTo3MCIsInVybCI6InNjcmVlbnNob3RzL3Bob3RvczJfZmFjZWFwcC9jb21wYXJlLzIwMjQtMTEtMTAtMjItMjItMTgtLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMTc0MTIsImV4cCI6MTgyMTY1MzQxMn0.GFN3TADnOlXVV_Zo4BrXd3KYS7SlEjXsxqXVzh_wARM)

### 11.2 Review

| Region | Component | States | Copy |
|---|---|---|---|
| Header leading | `ProgressCounter` | loading · counting · done | `"12 / 340"` |
| Header trailing | two icon buttons, `DSSize.iconChrome` | Trash with a count badge · Library | — |
| Body | `CardStack` + `ScreenshotCard` | loading · reviewing · exiting · rewinding | date chip `"Sep 21 · 2:14 PM · 1.2 MB"` |
| Overlay | `VerdictStamp` ×3 | hidden · revealing · committed | TRASH · ARCHIVE · FAVE |
| Bottom | `VerdictButtonRow` + `RewindButton` | enabled · pressed · disabled | captions `"Trash"` `"Fave"` `"Archive"` `"Rewind"` |
| Empty | `EmptyState` | allDone · noScreenshots | see below |

**Queue model.** One queue, newest unreviewed first. A restored item returns to unreviewed and
lands back in date order, so it surfaces where the user expects it rather than jumping to the
front. Screenshots taken during a session join silently through `PHPhotoLibraryChangeObserver` —
the total in the counter goes up, nothing is reordered under the user's thumb.

**All done.** `DSBlock.allDone` (lime, `delighted` face): headline
`"Inbox zero, screenshot edition."`, body `"Trash is holding 27 — empty it whenever."`, CTA
`"Open Trash (27)"`. A confetti burst plays for `DSMotion.confetti`, gated on Reduce Motion. Rewind stays available.

**No screenshots.** `"No screenshots. Honestly, impressive."`

**Permission lost.** Not an `EmptyState` case. If authorization is revoked while the app is
backgrounded, Review returns to the Permission screen's denied state (`DSBlock.denied`, violet)
rather than showing an empty queue.

### 11.3 Trash

| Region | Component | States | Copy |
|---|---|---|---|
| Header | `DSTextRole.title` | — | `"Trash · 27 items · 48 MB"` |
| Body | grid of `ThumbnailCell(.trash)` | populated · removing · empty | most recently trashed first |
| Tap / long press | `AssetViewer` or context menu | — | `"Restore"` · `"Delete permanently"` |
| Docked | destructive button | default · pending · disabled when empty | `"Delete all permanently (27 · 48 MB)"` |
| Empty | `EmptyState` on `DSBlock.trashEmpty` | — | `"Trash is empty. Squeaky."` |

`DSSize.gridColumns` columns, `DSSize.thumbnailGutter` gutter, square center crops. There is no
multi-select (ADR-015): one item or all of them covers a holding pen, and a selection mode would
add a toolbar and a set of edge cases for very little.

**Purge one.** No in-app confirmation. `DSHaptic.purgeArmed` fires, then `deleteAssets` presents
the iOS dialog, which is the one confirmation. On success the cell fades out over `DSMotion.fade`
and `DSHaptic.purgeDone` fires.

**Purge all.** `PurgeAllSheet` first:

- Title: `"Delete 27 screenshots permanently?"`
- Body: `"They leave \(Brand.name) for good and go to Photos' Recently Deleted for 30 days. iOS will double-check — that's expected."`
- Buttons: `"Delete 27 permanently"` · `"Keep them"`

The sheet names the count and not the size. The size is on the docked button that opens it,
`"Delete all permanently (27 · 48 MB)"`, which is where the user is still deciding whether to open
the sheet at all; inside the sheet the scope is already all of them, and what the destructive label
owes is the count, so that it stays unambiguous out of context
([§10 PurgeAllSheet](#purgeallsheet)).

The body pre-announces the second dialog so the double confirmation reads as designed rather than
as a bug. After the sheet dismisses, `DSHaptic.purgeArmed` fires and `deleteAssets` presents the
system dialog. Cells fade out over `DSMotion.fade`, each starting `DSMotion.stagger` after the previous one.

**Cancellation and failure.** Cancelling the system dialog leaves Trash untouched and posts the
toast `"Not deleted"`. A partial failure shows an inline line: `"Couldn't delete 3. Try again."`

### 11.4 Library

| Region | Component | States | Copy |
|---|---|---|---|
| Header | `DSTextRole.title` + `SegmentedControl` | Favorites · Archive | `"Favorites (12)"` · `"Archive (58)"` |
| Body | grid of `ThumbnailCell(.library)` | populated · removing · empty | — |
| Tap | `AssetViewer` | — | `"Move to Archive"` / `"Move to Favorites"` · `"Trash"` |
| Empty (Favorites) | `EmptyState` on `DSBlock.favoritesEmpty` | — | `"No faves yet. Swipe up on the good ones."` |
| Empty (Archive) | `EmptyState` on `DSBlock.archiveEmpty` | — | `"Nothing archived. Swipe right to stash keepers."` |

Favorites lists screenshots with `isFavorite` set; Archive lists the app's archive list, which the
`Brand.archiveAlbumTitle` album mirrors (ADR-025, A4). An asset can be in both and then appears in both. Moving an asset
from one segment to the other sets the destination and clears the source. Trashing from the viewer
needs no confirmation (rung 0 below) and fires `DSHaptic.trash`.

### Destructive-action ladder

The axis is recoverability *after* the user confirms, not how scary the wording is (ADR-009).

| Rung | Actions | Recoverable after confirm | Confirmation | Haptic |
|---|---|---|---|---|
| 0 | swipe and button verdicts, viewer Trash, Library moves, Restore | yes | none — Trash and rewind are the net | verdict `.impact` · restore `.success` |
| 1 | Delete permanently, one item | no (Photos' Recently Deleted holds it 30 days) | the iOS dialog is the one confirmation | `.warning` → `.success` |
| 2 | Delete all permanently | no | in-app sheet naming the count, then the iOS dialog | `.warning` → `.success` |

Rung 0 has no confirmation on purpose. A confirmation on every swipe would make the core loop
unusable, and everything at rung 0 is undoable by design.

**Correction, 2026-09-24.** Rung 2 used to read "in-app sheet with count and size". The sheet has
three strings, `"Delete 27 screenshots permanently?"`, its body, and `"Delete 27 permanently"`
([§11.3](#113-trash), [§12](#12-copy-and-voice)), and none of them carries a size; the size belongs to
the docked button that opens the sheet. `design-system.html` carries the same error in the caption
under its sheet mock, which says the sheet "names the count and the size" while the mock it captions
renders the count alone. That file is outside this document's scope; the string to search for there is
`names the count and the size`.

---

## 12. Copy and voice

**Verbs first.** A button says what it does: "Show me the screenshots", "Open Settings", "Pick
more", "Keep them". Not "Continue", not "OK".

**Playful only in titles and empty states.** "Inbox zero, screenshot edition." and "Trash is empty.
Squeaky." are allowed because nothing is at stake there. A destructive button is never playful.

**"Trash" is always reversible; "permanently" is only ever irreversible.** The swipe word is TRASH
because the destination is the Trash screen, and "Delete" is reserved for the action that cannot be
undone (ADR-013). No string uses "delete" for a reversible action or "trash" for an irreversible
one.

**Destructive buttons carry a number.** "Delete all permanently (27 · 48 MB)", "Delete 27
permanently". A number tells the user the scale of what they are about to lose without their having
to count.

**Do not promise "gone".** Permanently deleted assets sit in Photos' Recently Deleted for 30 days.
The purge sheet says so.

**The app's name is a verb in the product copy** — "`\(Brand.name)` your screenshots.", "`\(Brand.name)`
these 14" — which is a reason to keep it in one constant: a rename changes these strings
automatically.

Example strings, all from the screens above:

| Context | String |
|---|---|
| Permission headline | `"\(Brand.name) your screenshots."` |
| Permission CTA | `"Show me the screenshots"` |
| Limited interstitial | `"You picked 14 screenshots. \(Brand.name) only sees those."` |
| Limited actions | `"Pick more"` · `"\(Brand.name) these 14"` |
| Denied | `"\(Brand.name) can't see your screenshots yet."` · `"Open Settings"` · `"Not now"` |
| Card chip | `"Sep 21 · 2:14 PM · 1.2 MB"` |
| All done | `"Inbox zero, screenshot edition."` · `"Trash is holding 27 — empty it whenever."` · `"Open Trash (27)"` |
| No screenshots | `"No screenshots. Honestly, impressive."` |
| Trash header | `"Trash · 27 items · 48 MB"` |
| Purge-all button | `"Delete all permanently (27 · 48 MB)"` |
| Purge-all sheet | `"Delete 27 screenshots permanently?"` · `"They leave \(Brand.name) for good and go to Photos' Recently Deleted for 30 days. iOS will double-check — that's expected."` · `"Delete 27 permanently"` · `"Keep them"` |
| Trash empty | `"Trash is empty. Squeaky."` |
| Delete failure | `"Couldn't delete 3. Try again."` |
| Delete cancelled | `"Not deleted"` |
| Library empty | `"No faves yet. Swipe up on the good ones."` · `"Nothing archived. Swipe right to stash keepers."` |
| VoiceOver announcement | `"Trashed. 13 of 340"` |

---

## 13. Accessibility

### Contrast bar

Text 4.5:1. Large text and non-text 3:1, where large text means 24 pt regular or larger, or 19 pt
bold or larger. Bold at a body or label size is not large text: the 16 pt bold `label` owes the full
4.5:1, not 3:1. Informational rows are exempt and are marked as such in the table. The script fails
the build on any regression, so the bar is enforced rather than documented. Three of the 43 rows are
informational: the two `fave.main` edge rows, which the yellow exemption covers (ADR-004), and
`surfaceRaised` against `canvas`, which is tint separation and not a boundary anyone needs to see.

There is exactly one measured exception to "a white label on a verdict fill is large text only".
`archive.on` is white and `archive.main` is cobalt, and that pair measures 6.57, which clears 4.5 as
normal text. The table prints that pair twice for that reason: once under
`large text · stamp word (32 pt) and button glyph on main` at the 3:1 bar and once under
`text · white label on a cobalt fill` at the 4.5 bar, both PASS. So a white label on cobalt is legal
at any size, where white on tomato is 3.51 and is legal only for the 32 pt stamp word and the
glyphs. The exception is cobalt's alone; nothing generalises from it. `fave.on` also clears 4.5 on its own `main`, at 10.20, but that
is not a second exception: `fave.on` is `ink`, the same navy every other label on a verdict fill
already uses.

### Dynamic Type

Ten of the eleven `DSTextRole` cases bind to a text style through `relativeTo:` and scale with it,
the display roles included. `stamp` is the one exception, and it is the first defense below. Two
specific defenses:

- The stamp binds to no text style. `DSTextRole.stampFont(size:)` clamps to
  `DSTextRole.stampMaxSize` and returns a fixed-size font, so the 44 pt cap cannot be scaled past a
  second time and the stamp cannot outgrow the card. Dynamic Type for it belongs to the call site,
  which owns `@ScaledMetric(relativeTo: .largeTitle)`.
- `caption` is never used above `body` in the hierarchy, because `.footnote` and `.body` converge
  at accessibility sizes.

Scaling never changes which color is legal on a fill, so a role is colored for its design size and
keeps that color at every Dynamic Type step. The 16 pt bold `label` is `ink` on `trash.main` because
4.61 clears 4.5; it does not become eligible for `trash.on` once Dynamic Type carries it past 19 pt.
The one pair that is legal at both bars is white on cobalt, `archive.on` on `archive.main` at 6.57,
which is why a white label on cobalt is unchanged at any size while white on tomato stays confined
to the 32 pt stamp word and the glyphs. See [Contrast bar](#contrast-bar) above and
[§1 Usage rules](#usage-rules).

Layouts wrap rather than truncate. A destructive button's label may go to two lines; it may not be
shortened, because the count has to stay visible.

### Reduce Motion

Every animation goes through `DSMotion.gated(_:reduce:)` or `DSMotion.gated(_:reduce:reduced:)`; the
second swaps in a named substitute (`DSMotion.snapBackReduced`, `DSMotion.crossFade`) instead of
removing the animation. See the [Reduce Motion table](#reduce-motion-variants) in §6. The principle:
direct manipulation and feedback stay, interpretation goes, and anything that still has to happen is
substituted rather than deleted. Under `reduceTransparency` the card chip becomes solid `surface` instead of
`chip`.

### VoiceOver

**The card is one element.** Label: `"Screenshot, Sep 21, 2:14 PM, 1.2 MB, 12 of 340"`. Stamps and
the cards behind the front card are `accessibilityHidden`.

**Custom actions, in this order:** Trash, Archive, Favorite, Rewind last. The three verdicts come
first because they are the loop; rewind is last because it is the exception. Note that the action
is named "Favorite" even though the stamp reads FAVE — the stamp is display typography, the action
is language.

**Announcements.** After a commit:
`AccessibilityNotification.Announcement("Trashed. 13 of 340")`. The verdict and the new position in
one sentence, so a VoiceOver user gets the same two facts a sighted user reads off the stamp and
the counter.

**Focus.** `@AccessibilityFocusState` moves focus to the new front card after a commit. In
`PurgeAllSheet`, focus moves to the title on present and returns to the docked button on dismiss.
The toast never takes focus.

### Touch targets

`DSSize.tapMin` is 44 pt and is a floor for every interactive element. The rewind button is exactly
44 pt; the verdict circles are 56 and 64. Where a glyph is smaller than the target — a header icon
at `DSSize.iconChrome` — the *hit area* is padded to 44, never the glyph.

### Color is never alone

Each verdict carries four channels: a direction, a glyph, a word, and a hue. Removing the hue —
which is what a monochrome display or a strong CVD does — leaves three. This is also why the
verdict buttons keep their captions instead of relying on color-coded circles, and why the Trash
count badge shows a number rather than a colored dot.

---

## 14. Token index

Swift token → CSS custom property, as emitted by `python3 "scripts/ds_tokens.py" emit-css` into
`scripts/out/tokens.css`. The guide pastes that block verbatim; the lint fails if it is stale.

### Colors

| Swift | CSS variable | Value |
|---|---|---|
| `DSColor.canvas` | `--color-canvas` | `#ffffff` |
| `DSColor.surface` | `--color-surface` | `#ffffff` |
| `DSColor.surfaceRaised` | `--color-surface-raised` | `#e9e9e9` |
| `DSColor.toast` | `--color-toast` | `#1f1e38` |
| `DSColor.chip` | `--color-chip` | `rgb(255 255 255 / 0.90)` |
| `DSColor.ink` | `--color-ink` | `#1f1e38` |
| `DSColor.ink2` | `--color-ink2` | `#535366` |
| `DSColor.inkMuted` | `--color-ink-muted` | `#656571` |
| `DSColor.onToast` | `--color-on-toast` | `#ffffff` |
| `DSColor.onImage` | `--color-on-image` | `#ffffff` |
| `DSColor.accent` | `--color-accent` | `#1f1e38` |
| `DSColor.onAccent` | `--color-on-accent` | `#ffffff` |
| `DSColor.focus` | `--color-focus` | `rgb(31 30 56 / 0.60)` |
| `DSColor.trash.main` | `--color-trash` | `#eb5927` |
| `DSColor.trash.on` | `--color-trash-on` | `#ffffff` |
| `DSColor.trash.soft` | `--color-trash-soft` | `#ffe0d7` |
| `DSColor.archive.main` | `--color-archive` | `#3d44e8` |
| `DSColor.archive.on` | `--color-archive-on` | `#ffffff` |
| `DSColor.archive.soft` | `--color-archive-soft` | `#e1e7fc` |
| `DSColor.fave.main` | `--color-fave` | `#f3c935` |
| `DSColor.fave.on` | `--color-fave-on` | `#1f1e38` |
| `DSColor.fave.soft` | `--color-fave-soft` | `#fdefba` |
| `DSColor.mint` | `--color-mint` | `#7cd2ae` |
| `DSColor.violet` | `--color-violet` | `#5849b2` |
| `DSColor.lime` | `--color-lime` | `#e0fc41` |
| `DSColor.pink` | `--color-pink` | `#f6c1e9` |
| `DSColor.lavender` | `--color-lavender` | `#b98cea` |
| `DSColor.scrim` | `--color-scrim` | `rgb(31 30 56 / 0.35)` |
| `DSColor.shadowNear` | `--color-shadow-near` | `rgb(31 30 56 / 0.10)` |
| `DSColor.shadowFar` | `--color-shadow-far` | `rgb(31 30 56 / 0.05)` |

Three names are not a literal transliteration, and they are the three verdict `main` tokens:
`trash.main` → `--color-trash`, `archive.main` → `--color-archive`, `fave.main` → `--color-fave`.
The suffix is dropped because in CSS the base name is the fill. Everything else in the table is the
mechanical rule in `css_name` and `kebab`: a dot becomes a hyphen (`trash.on` → `--color-trash-on`)
and a hyphen is inserted before each capital.

**Correction, 2026-09-24.** This note used to name three exceptions and get two of them wrong.
`surfaceRaised` → `--color-surface-raised` is the kebab rule itself, not a departure from it, as
`inkMuted`, `onToast` and `shadowNear` all show; the old wording even said "like every other
camel-cased token" while calling it an exception. `ink2` → `--color-ink2` is the rule too: `kebab`
inserts a hyphen before a capital and never before a digit, so nothing special happens to the digit.
The real count of names the script does not transliterate literally is three, and all three are the
dropped `.main`.

### Spacing, radius, grid

| Swift | CSS variable | Value |
|---|---|---|
| `DSSpace.s1` | `--space-s1` | `6px` |
| `DSSpace.s2` | `--space-s2` | `8px` |
| `DSSpace.s3` | `--space-s3` | `12px` |
| `DSSpace.s4` | `--space-s4` | `16px` |
| `DSSpace.s5` | `--space-s5` | `24px` |
| `DSSpace.s6` | `--space-s6` | `28px` |
| `DSSpace.s7` | `--space-s7` | `32px` |
| `DSRadius.xs` | `--radius-xs` | `6px` |
| `DSRadius.sm` | `--radius-sm` | `8px` |
| `DSRadius.md` | `--radius-md` | `12px` |
| `DSRadius.lg` | `--radius-lg` | `16px` |
| `DSRadius.xl` | `--radius-xl` | `24px` |
| `DSRadius.pill` | `--radius-pill` | `999px` |
| `DSGrid.breakpoint` | `--grid-breakpoint` | `1200px` |
| `DSGrid.desktopColumns` | `--grid-desktop-columns` | `14` |
| `DSGrid.desktopGutter` | `--grid-desktop-gutter` | `24px` |
| `DSGrid.mobileColumns` | `--grid-mobile-columns` | `4` |
| `DSGrid.mobileMargin` | `--grid-mobile-margin` | `16px` |
| `DSGrid.mobileGutter` | `--grid-mobile-gutter` | `8px` |

### Sizes

| Swift | CSS variable | Value |
|---|---|---|
| `DSSize.tapMin` | `--size-tap-min` | `44px` |
| `DSSize.verdictButton` | `--size-verdict-button` | `64px` |
| `DSSize.faveButton` | `--size-fave-button` | `56px` |
| `DSSize.faveButtonRaise` | `--size-fave-button-raise` | `8px` |
| `DSSize.rewindButton` | `--size-rewind-button` | `44px` |
| `DSSize.cardInset` | `--size-card-inset` | `12px` |
| `DSSize.thumbnailGutter` | `--size-thumbnail-gutter` | `4px` |
| `DSSize.stackOffsetY` | `--size-stack-offset-y` | `14px` |
| `DSSize.stackScaleStep` | `--size-stack-scale-step` | `0.06` |
| `DSSize.stampFaveRaise` | `--size-stamp-fave-raise` | `0.12` |
| `DSSize.iconVerdict` | `--size-icon-verdict` | `28px` |
| `DSSize.iconChrome` | `--size-icon-chrome` | `24px` |
| `DSSize.iconInline` | `--size-icon-inline` | `20px` |
| `DSSize.stampIcon` | `--size-stamp-icon` | `24px` |
| `DSSize.focusRing` | `--size-focus-ring` | `3px` |
| `DSSize.gridColumns` | `--size-grid-columns` | `3` |
| `DSSize.stackDepth` | `--size-stack-depth` | `3` |

### Swipe

| Swift | CSS variable | Value |
|---|---|---|
| `DSSwipe.commitDistance` | `--swipe-commit-distance` | `120px` |
| `DSSwipe.commitVelocity` | `--swipe-commit-velocity` | `800` |
| `DSSwipe.minTravelForVelocity` | `--swipe-min-travel-for-velocity` | `48px` |
| `DSSwipe.rotationDivisor` | `--swipe-rotation-divisor` | `20` |
| `DSSwipe.maxRotationDegrees` | `--swipe-max-rotation-degrees` | `12` |
| `DSSwipe.stampTiltDegrees` | `--swipe-stamp-tilt-degrees` | `12` |
| `DSSwipe.stampRevealStart` | `--swipe-stamp-reveal-start` | `20px` |
| `DSSwipe.stampRevealEnd` | `--swipe-stamp-reveal-end` | `120px` |
| `DSSwipe.sectorHysteresisDegrees` | `--swipe-sector-hysteresis-degrees` | `6` |
| `DSSwipe.exitDistanceX` | `--swipe-exit-distance-x` | `720px` |
| `DSSwipe.exitDistanceY` | `--swipe-exit-distance-y` | `840px` |
| `DSSwipe.exitRotationDegrees` | `--swipe-exit-rotation-degrees` | `18` |
| `DSSwipe.downFollow` | `--swipe-down-follow` | `0.35` |
| `DSSwipe.upScale` | `--swipe-up-scale` | `1.03` |
| `DSSwipe.promoteAt` | `--swipe-promote-at` | `0.6` |
| `DSOpacity.disabled` | `--opacity-disabled` | `0.45` |

Angles, velocities, the rotation divisor and the three bare ratios (`--swipe-down-follow`,
`--swipe-up-scale`, `--swipe-promote-at`) are emitted unitless because they are not lengths; the CSS
side applies `deg` or `ms` at the point of use. Everything that *is* a length carries `px`, including
`--swipe-min-travel-for-velocity`.

### Motion

| Swift | CSS variable | Value |
|---|---|---|
| `DSMotion.dur1` | `--motion-dur1` | `0.12s` |
| `DSMotion.dur2` | `--motion-dur2` | `0.18s` |
| `DSMotion.dur3` | `--motion-dur3` | `0.24s` |
| `DSMotion.buttonFlick` | `--motion-button-flick` | `0.28s` |
| `DSMotion.exitMin` | `--motion-exit-min` | `0.18s` |
| `DSMotion.exitMax` | `--motion-exit-max` | `0.32s` |
| `DSMotion.fade` | `--motion-fade` | `0.18s` |
| `DSMotion.stampHoldReduced` | `--motion-stamp-hold-reduced` | `0.25s` |
| `DSMotion.stampPopScale` | `--motion-stamp-pop-scale` | `1.15` |
| `DSMotion.toastVisible` | `--motion-toast-visible` | `2.5s` |
| `DSMotion.confetti` | `--motion-confetti` | `0.6s` |
| `DSMotion.stagger` | `--motion-stagger` | `0.02s` |

### Declared but not consumed

Three generated variables are declared in the guide's `:root` block and never read by any rule in
it. `ds_tokens.py lint` counts usage by exact variable name, outside HTML comments, and prints an
`EXCEPTION` line for each of these on every run rather than tolerating it silently. Any other unused
variable is a lint failure, not an exception.

| CSS variable | Swift | Recorded reason |
|---|---|---|
| `--grid-breakpoint` | `DSGrid.breakpoint` | CSS media queries cannot take `var()`; the guide's twelve `max-width` queries spell `1199.98px` literally |
| `--motion-dur3` | `DSMotion.dur3` | surface transitions (sheet, card expand); the guide has no animated sheet |
| `--motion-toast-visible` | `DSMotion.toastVisible` | the toast demo is a static swatch, so nothing counts down 2.5 s |

The reason strings above are quoted from `DECLARATION_ONLY` in `scripts/ds_tokens.py`, so they are
what a `lint` run prints, with one em-dash rewritten as a semicolon because this document keeps
em-dashes out of table cells. `--grid-breakpoint`'s string used to read "the two `@media` rules repeat
1200px literally", and both halves of that were wrong: the guide implements the breakpoint in twelve
`@media (max-width: 1199.98px)` blocks, not two, and each spells `1199.98px`, the largest width below
the breakpoint, so 1200 px itself belongs to the desktop rule. On 2026-09-24
`grep -c '@media (max-width: 1199\.98px)' design-system.html` returned 12. The script and ADR-022 now
both carry the corrected wording; the table above quotes the current string.

**Correction, 2026-09-24.** A parenthesis here used to read "Four further `max-width` queries exist,
three at 1040px and one at 340px, and none of them is the breakpoint", and it was wrong twice. None of
them is a query: every one is a `max-width` *property* on an element, and a CSS property and a media
feature share a name and nothing else. And there are eight, not four. On 2026-09-24
`grep -o 'max-width: [^;)]*' design-system.html | grep -v 1199.98 | sort | uniq -c` returned 1040px
three times and one each of 340px, 100 %, 20ch, 58ch and 66ch, on `.wrap`, `.hero__inner`, `.hero h1`,
`.hero p`, `.section__lead`, `.phone`, `.compass` and `.footer`. This is the kind of number to
re-derive rather than read.

The literal `1200px` appears in the guide twice, and `grep -c '1200px' design-system.html` returned 2
on 2026-09-24: the `--grid-breakpoint` declaration itself, and a CSS comment marking the desktop type
block. Neither is a `var(--grid-breakpoint)` reference, which is exactly why nothing consumes the
variable and why it is an `EXCEPTION` rather than a failure.

### Not emitted as CSS

`DSLayer` (`DSLayer.base`, `DSLayer.sticky`, `DSLayer.dropdown`, `DSLayer.modal`, `DSLayer.toast`),
`DSShadow`, `DSTextRole` and its `stampBaseSize` / `stampMaxSize`, `DSHaptic`, `DSIcon`, `DSFace`
and `DSBlock` have no CSS variables. The guide reproduces the z ladder and the type scale in its own
CSS; haptics, icons and faces are documented rather than demonstrated, except in the guide's swipe
demo, which implements the physics in JavaScript from the `--swipe-*` and `--motion-*` variables.

---

## 15. Open questions

Eight, carried from the approved interaction spec and from the build. None of them is a question
about a token value: those are settled by the four verification commands in
[§0](#the-four-commands) — `contrast`, `emit-css`, `lint` and `scripts/typecheck-ds.sh` — which fail
the build rather than leaving a number open. Two things that used to read as open are also settled
and are recorded where they belong instead of here: ADR-016 allows exactly two colors from outside
the expressive palette to serve as blocks, `onboarding` on `trash.main` and `limited` on `fave.soft`
([§9](#9-illustration)), and the text-on-`main` rule is fixed at the stamp word and the glyphs only
([§1 Usage rules](#usage-rules)).

1. **Album writes under limited access.** PhotoKit may refuse to create or modify the
   `Brand.archiveAlbumTitle` album when access is limited. If it does, only the mirror write is
   skipped: the archive list is the truth on every path (ADR-025, A4) and the album catches up when
   access widens. What to verify on a device during the app phase is only whether the refusal
   happens at all (ADR-010, Correction of 2026-09-27).
2. **FAVE or FAVORITE on the stamp.** "FAVE" fits at stamp size and matches the playful voice, but
   it is slang and may not localize. Current proposal, and what is implemented: FAVE on the stamp,
   "Favorite" in the caption and in VoiceOver. Revisit when a second language is added.
3. **Rewind history lifetime.** Current proposal, and what is implemented: history survives
   navigating to Trash or Library within a session and is cleared on cold launch. Whether it should
   survive a background-and-return is open.
4. **File size on the card chip.** Reading `PHAssetResource` for a size is not free. Current
   proposal: pre-read three cards ahead; if promoting the next card ever blocks for more than one
   frame, drop the size and show the date alone.
5. **The block behind `noScreenshots`.** `EmptyState` has five states ([§10](#emptystate)) and
   `DSBlock` has seven cases ([§9](#color-blocks)), every one of them already spoken for: onboarding,
   the four empty states that name a block, denied and limited. Review's `noScreenshots` state is
   therefore the only `EmptyState` with no block of its own. Either `DSBlock` gains a case or
   `noScreenshots` names the block it borrows, before Review ships. (The kit-weight question that
   stood here is closed: `blt4ith` serves `forager-overlap` at 400 and 700, Forager Overlap has no
   heavier cut, and no role asks for one.)
6. **Forager Bold Overlap app license.** Not purchased. Until it is,
   `DSFont.availableDisplayNames` comes back empty, `DSFont.resolvedDisplay(_:)` returns
   `Pretendard-Bold`, and every display role in the app is set in Pretendard Bold (ADR-003).
   Because Forager Overlap is a single cut, a license restores all four display roles at once: there
   is no half-licensed state in which `headline` and `title` come back while `display` and `stamp`
   stay on the fallback.
7. **Noun Project icons not downloaded.** `DSIconCredits.entries` is empty, so the credits screen
   says no third-party icons ship yet and every `DSIconRef.image` returns its SF Symbol fallback.
   The twelve `query` strings in [§8](#8-icons) are the shopping list.
8. **PostScript name unverified.** `Forager-BoldOverlap` is the expected name; confirm it against
   `UIFont.familyNames` the first time the file is in the bundle, because a wrong name fails
   silently into the fallback and the guide would keep showing the licensed face while the app did
   not. This is the whole of what is still open here.

   The duplicate-key half of this item is closed, and it was stated wrongly while it was open.
   `DSFont.displayBold` and `DSFont.displayBlack` hold the same string, and the old
   `DSFont.displayAvailability` was a dictionary *literal* with those two keys. A Swift dictionary
   literal with duplicate keys traps at construction, not at some later lookup, so the cost was a
   crash on the first display role the app rendered, not a wasted entry. `DSTypography.swift` now
   declares `DSFont.availableDisplayNames`, a `Set<String>` built in a closure that probes each name
   on its own and inserts the ones that resolve, so splitting the family later still falls back one
   cut at a time ([§2 License note](#license-note-adr-003)).

---

## Changelog

| Version | Date | Change |
|---|---|---|
| v1.0 | 2026-09-23 | First write, from the approved interaction spec and ADR-001 to ADR-020. |
| v1.1 | 2026-09-24 | Code-review corrections. Large text restated as 24 pt regular or 19 pt bold, so the 16 pt bold `label` owes 4.5:1; the focus ring's 60 % alpha and its two rows recorded (ADR-021); `stamp` documented as scaled at the call site and returned fixed-size; the four verification commands and `lint`'s EXCEPTION and WARNING lines described (ADR-022). |
| v1.2 | 2026-09-24 | Token corrections. The destructive button named as a `trash.main` fill with a navy `ink` label at 4.61:1; the two blocks that borrow a verdict color named in §1 and §9; the face rule restated as round parentheses plus one world-script glyph; the `--grid-breakpoint` exception wording corrected against the guide's twelve `1199.98px` queries. |
| v1.3 | 2026-09-24 | Propagation of the `DSBlock` and `DSFont` changes. §9 and §10: the block CTA is `DSBlock.ctaFill` with `DSBlock.ctaLabel` and the block focus ring is `DSBlock.focusRing`, replacing the free choice between a navy and a white pill and replacing `DSColor.focus` on a block. §1: the contrast block regenerated at 43 pairs, 0 failures, and the 60/30/10 rule corrected to four places. §2: `DSFont.availableDisplayNames` replaces `displayAvailability`, and the `0.06em` stamp tracking recorded as a rounding of 0.0625 em. §13: the cobalt exception stated. §14: the CSS-name note recounted. §0: the type list completed and `README.md` removed from the prose that names the product. |
| v1.4 | 2026-09-24 | Citation and reconciliation pass. Every cross-file line citation and every contrast-row number replaced by a token pair, a quoted `Use` string, a selector or a recorded command; the product-name tally recounted (`design-system.html` 10, not 8) and restated as a rule; §9 and §10 reconciled on one filled action per block, with the second action bare text in the block's ink and a fifth button kind for it; §5 restated for `.dsFocusRing`'s `color:` parameter and the measurement that covers a block; rung 2 of the destructive ladder corrected to the count alone; §14's `max-width` parenthesis corrected from four queries to eight properties; `ink2` 6.19 and `inkMuted` 4.77 folded in from the `DSColor` comments. |
