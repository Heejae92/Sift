# Sift · Information architecture

v1.2 · 2026-09-28 · status: Active (ADR-025, the four assumptions confirmed by the owner on 2026-09-27; the 30-day rule of ADR-032 and its follow-ups in ADR-033, chosen by the owner on 2026-09-28) · English

This file is the structure the screens hang on: what the app is made of, how the pieces are
organised, how the user moves between them, and what the app does when Photos changes underneath
it. It sits between the design system and the code. `UI_DESIGN.md` says what each screen looks
like; `IA.md` says what exists, where it lives and how it connects. `ia.html` is the same content
drawn as diagrams. Nothing here restates a token or a string; it points at the section that owns
it.

The product name is `Brand.name` in code and appears in prose only where a rename would have to
change it.

## Contents

- [0. Scope](#0-scope)
- [1. Object model](#1-object-model)
- [2. Screen inventory](#2-screen-inventory)
- [3. Navigation map](#3-navigation-map)
- [4. Launch routing](#4-launch-routing)
- [5. Queue lifecycle](#5-queue-lifecycle)
- [6. Actions and where they lead](#6-actions-and-where-they-lead)
- [7. Persistence](#7-persistence)
- [8. External change](#8-external-change)
- [9. System surfaces](#9-system-surfaces)
- [10. Assumptions, confirmed](#10-assumptions-confirmed)
- [11. Out of scope for v1](#11-out-of-scope-for-v1)

---

## 0. Scope

The app has one job: put every screenshot in the user's Photos library into one of three piles,
one card at a time. The information architecture therefore has one object that matters (a
screenshot), three places it can end up, one derived list (the queue), and four screens. Everything
else is a sheet, a cover or a system dialog on top of those four.

What this document decides:

- which objects exist and which of their properties are the app's to write;
- which screens exist, what each one is for, and how they nest;
- the routing rule at launch and on every return to the foreground;
- the lifecycle of the queue and the exact side effect of every action;
- what is persisted, where, keyed by what, and what is deliberately not persisted;
- how the app reconciles with edits made in the Photos app.

What it does not decide: layout, copy, color, motion, haptics (`UI_DESIGN.md`), the reasons behind
settled choices (`DECISIONS.md`), or how the code is organised into modules (`ARCHITECTURE.md`,
written in the app phase).

---

## 1. Object model

| Object | What it is | Identity | Who writes it |
|---|---|---|---|
| Screenshot | A `PHAsset` in the Screenshots smart album (`.smartAlbumScreenshots`) | `localIdentifier` | Photos |
| Trash entry | `(localIdentifier, trashedAt)` — the screenshot is in the app's holding pen; the asset itself is untouched in Photos | `localIdentifier` | the app, app-local store |
| Archive entry | `(localIdentifier, archivedAt)` — the screenshot was kept; mirrored into the `Brand.archiveAlbumTitle` album so it is visible in Photos | `localIdentifier` | the app, app-local store; album via PhotoKit |
| Favorite | `PHAsset.isFavorite == true` — Photos is the truth, there is no app-side copy | — | the app on FAVE, or the user in Photos |
| Rewind entry | The last committed verdict: `(localIdentifier, verdict, favoriteWasSet)` | — | the app, memory only |
| Authorization | `PHAuthorizationStatus` for `.readWrite` | — | the system |
| Acknowledged selection | Under limited access, the number of selected assets the user last dismissed the interstitial for | — | the app, app-local store |

**A verdict is not a field.** TRASH, ARCHIVE and FAVE are the three memberships above. Nothing
stores "this screenshot was reviewed"; the queue is derived:

1. `unreviewed(s)` = not in the trash list, not in the archive list, not favorited.
2. **Queue** = every screenshot with `unreviewed(s)` that is also **due**: taken at least 30 days
   (`ReviewPolicy.minimumAgeDays`) before the reference date, the boundary included, counted as
   30 × 86 400 s. Newest first (`creationDate` descending); the front card is the newest due
   unreviewed screenshot. An unreviewed screenshot that is not due yet is **waiting**: it is on no
   screen, and it joins the queue by itself once it comes of age (ADR-032). The reference date is
   the moment of the last refresh — launch, return to the foreground, or a change in Photos — so the
   queue holds still between refreshes.
3. **Trash wins on display.** A screenshot in the trash list appears only in Trash, even if it is
   also favorited or archived. The app clears the other two when it trashes; the rule covers edits
   made in Photos afterwards.
4. **Library › Favorites** = favorited and not in the trash list. **Library › Archive** = in the
   archive list and not in the trash list. A screenshot can be in both segments (the user hearted
   an archived one in Photos) and then appears in both.
5. **Counter.** `total` = number of screenshots the app can see; `reviewTotal` = the due ones
   among them, reviewed or not; `reviewed` = `reviewTotal` minus the queue length. The header shows
   `reviewed + 1 / reviewTotal` while a card is up; when the queue is empty the all-done block takes
   its place, and the last announcement reads `reviewTotal of reviewTotal`. A waiting screenshot
   counts in `total` only and joins `reviewTotal` when it comes due, so when every screenshot is
   waiting `reviewTotal` is 0 and there is no count to show (ADR-032).

Consequences worth stating once: a screenshot the user hearted in Photos before ever opening the
app is already a Favorite and never enters the queue (A1, [§10](#10-assumptions-confirmed));
un-hearting it in Photos later puts it back in the queue by the same rule. The app owns no
"reviewed" flag that could drift from what Photos shows, and no "waiting" flag either: being due is
`creationDate` against the reference date, so a screenshot ages into the queue without a write.

---

## 2. Screen inventory

Four primary screens, three subordinate surfaces, four system surfaces. Nothing else exists in v1.

| # | Surface | Kind | Reached from | Leaves to | Blocks and empty states |
|---|---|---|---|---|---|
| P | **Permission** | gate; replaces the root while access is not usable | launch when status is not usable; Review when authorization is revoked | Review, on grant | `onboarding` (tomato), `denied` (violet), `limited` interstitial (pale yellow) |
| R | **Review** | root of the stack | Permission on grant; launch when access is usable | Trash and Library by push | `allDone` (lime), `noScreenshots` |
| T | **Trash** | pushed | Review header icon; the `allDone` CTA "Open Trash" | back; Viewer (trash actions); Purge-all sheet | `trashEmpty` (mint) |
| L | **Library** | pushed | Review header icon | back; Viewer (library actions); Credits | `favoritesEmpty` (pink), `archiveEmpty` (lavender) |
| V | **Viewer** | full-screen cover, black | a cell in Trash or Library | dismiss (swipe down, close) | two action sets, chosen by the presenting screen |
| S | **Purge-all sheet** | sheet over Trash | the docked destructive button | "Keep them" back to Trash; "Delete N permanently" to the iOS delete dialog | — |
| C | **Credits** | pushed | Library footer link | back | — |
| X1 | iOS photo-library dialog | system | Permission CTA | Review, the limited interstitial, or the denied state | — |
| X2 | Limited-library picker | system | "Pick more" on the limited interstitial | the interstitial with the new count | — |
| X3 | iOS delete dialog | system | Viewer "Delete permanently" (one); the Purge-all sheet (all) | Trash, with cells removed or the "Not deleted" toast | — |
| X4 | Settings app | external | "Open Settings" on the denied state | the app re-routes on the next `scenePhase == .active` | — |

Per-screen regions, components and strings are in `UI_DESIGN.md` §11; the blocks and their faces in
§9.

---

## 3. Navigation map

- **One `NavigationStack`, depth at most two.** Review is the root. Trash and Library push from
  the Review header. Credits pushes from Library. Nothing pushes from Trash.
- **Covers and sheets.** The Viewer is a full-screen cover over Trash or Library. The Purge-all
  sheet is a sheet over Trash. The limited-library picker and the two iOS dialogs are system-owned.
- **Permission is not on the stack.** While authorization is unusable the Permission screen *is*
  the root; on grant Review takes its place. If authorization is revoked while the app is in the
  background, the stack is discarded and Permission returns in its denied state — a Trash or
  Library the user left open is not preserved (`UI_DESIGN.md` §11.2, "Permission lost").
- **Back.** System back button and edge swipe on pushes; swipe down or the close button on the
  Viewer; "Keep them" or a swipe on the sheet. Dismissing a system dialog returns to whatever
  presented it.
- **Header ownership.** Review: `ProgressCounter` leading, Trash (with count badge) and Library
  trailing. Trash and Library: title leading, back trailing the system way. The Viewer has its own
  bar: date chip and close.
- **No tab bar** (ADR-011), no deep links, no URL scheme, no widgets, no Shortcuts in v1.

---

## 4. Launch routing

Evaluated at launch and again on every `scenePhase == .active`, so revocation, a return from
Settings and a change to the limited selection all land in the right place without a tap.

```
active
├── notDetermined            → Permission · onboarding
├── denied | restricted      → Permission · denied
├── limited
│   ├── selected ≠ acknowledged → Permission · limited interstitial
│   └── otherwise            → Review
└── authorized               → Review

Review
├── total == 0               → noScreenshots block
├── queue empty              → allDone block (Trash count and the next arrival in the copy),
│                              also when every screenshot is still waiting
└── otherwise                → deck
```

The interstitial's acknowledging action stores the number of screenshots picked as the acknowledged
selection, whatever its label counts; "Pick more" opens the picker and re-evaluates when it closes
(A2). When some of the picked screenshots are unreviewed and under 30 days old, the interstitial
says so in one line and names how many are ready now, and its action counts those ("Sift these 3");
when none is ready, the line names the day the first one comes due and the action reads "Continue",
after which Review opens on the all-done block (ADR-033). With nothing waiting it reads "Sift these
N", N being everything picked. When nothing picked is a screenshot, it says so, "Pick more" becomes
the filled action and "Continue" the text one, which goes on to the `noScreenshots` block.

---

## 5. Queue lifecycle

States of the Review screen:

| State | Meaning | Leaves on |
|---|---|---|
| `loading` | fetching the smart album and the three memberships | fetch complete → `reviewing`, `allDone` or `noScreenshots` |
| `reviewing` | a front card is up, input open | drag, button, key, rewind, external change |
| `dragging` | the front card follows the finger, sector re-evaluated on every move | release |
| `exiting` | the card is flying out; input closed | 60 % of the exit → `promoting` |
| `promoting` | side effect applied, next card fills in, counter updates | immediately → `reviewing` or `allDone` |
| `rewinding` | the last card flies back; input closed | landing → `reviewing` |
| `allDone` | queue empty, total > 0: every screenshot is reviewed or still waiting | rewind, restore, a move out of Library, an external un-heart, a new screenshot that is already due, a waiting screenshot coming due at a refresh |
| `noScreenshots` | total == 0 | a new screenshot: to `allDone` while it waits, to `reviewing` if it is already due |

Transitions and their triggers:

| From | Event | To | Side effect |
|---|---|---|---|
| `reviewing` | drag starts | `dragging` | — |
| `dragging` | release below threshold, or down sector | `reviewing` | snap back |
| `dragging` | release past `DSSwipe.commitDistance`, or `commitVelocity` with `minTravelForVelocity` | `exiting` | throw |
| `reviewing` | verdict button, arrow key, VoiceOver action | `exiting` | synthesized flick |
| `exiting` | 60 % of the exit duration | `promoting` | the verdict's side effect ([§6](#6-actions-and-where-they-lead)); rewind entry replaced |
| `promoting` | queue non-empty | `reviewing` | next card fades in |
| `promoting` | queue empty | `allDone` | `DSHaptic.queueDone` |
| `reviewing`, `allDone` | rewind, entry present | `rewinding` | side effect reversed exactly |
| `rewinding` | landing | `reviewing` | — |
| `allDone` | a due screenshot becomes unreviewed again, or a waiting one comes due at a refresh | `reviewing` | it takes its place by date |
| any | authorization revoked | Permission · denied | stack discarded |
| `reviewing`, `allDone` | a new screenshot under 30 days old appears | same state; `total` + 1, the counter unchanged | it waits ([§1](#1-object-model) rule 2) |
| `noScreenshots` | a new screenshot under 30 days old appears | `allDone` | it waits, and the block names the day it comes due; no burst and no `DSHaptic.queueDone`, since nothing was finished |
| `reviewing` | a new screenshot already 30 days old appears | same state; `total` and `reviewTotal` + 1 | it joins by date, behind the front card, never under the thumb |
| `allDone`, `noScreenshots` | a new screenshot already 30 days old appears | `reviewing` | `total` and `reviewTotal` + 1; it takes its place by date |
| `reviewing` | a waiting screenshot comes due at a refresh | same state, `reviewTotal` + 1 | it joins behind the front card, never under the thumb: as the newest due screenshot it would otherwise sort to the front |
| `reviewing` | the front screenshot is deleted in Photos | `promoting` | skipped silently, no verdict recorded |

**The counter counts what is due** (ADR-032). Its denominator is `reviewTotal`, the due screenshots,
reviewed or not ([§1](#1-object-model) rule 5): a screenshot taken mid-session leaves it alone, and
one that comes due raises it by one at the refresh that brings it in.

**Rewind holds exactly one entry** (ADR-008). It is replaced on every commit, cleared on cold
launch, cleared when the queue reaches its cap, and invalidated when its screenshot changes hands
elsewhere — restored from Trash, moved in Library, purged, or deleted in Photos — because there is
no longer a prior state to return to.

---

## 6. Actions and where they lead

Every action the user can take, and what it does to the three memberships.

| Where | Action | Trash list | Archive list · album | Favorite | Queue | Confirmation |
|---|---|---|---|---|---|---|
| Review | swipe left · Trash button | add | — | — | leaves | none |
| Review | swipe right · Archive button | — | add · add to album | — | leaves | none |
| Review | swipe up · Fave button | — | — | set true | leaves | none |
| Review | rewind | undo of the above, exactly, using the recorded prior favorite flag | | | returns to the front | none |
| Trash | Restore | remove | — | — | returns, by date | none |
| Trash | Delete permanently (one) | remove after success | — | — | — | the iOS dialog |
| Trash | Delete all permanently | remove all after success | — | — | — | the sheet, then the iOS dialog |
| Library › Favorites | Move to Archive | — | add · add to album | set false | — | none |
| Library › Archive | Move to Favorites | — | remove · remove from album | set true | — | none |
| Library, Viewer | Trash | add | remove · remove from album | set false | — | none |
| Permission | Show me the screenshots | — | — | — | — | the iOS photo-library dialog |
| Permission · limited | Pick more · Sift these N (the ready ones), or Continue when none are ready | — | — | — | re-evaluated | the picker; none |
| Permission · denied | Open Settings | — | — | — | — | leaves the app |

A Photos write happens on FAVE (the flag), on ARCHIVE (album membership) and on permanent deletion;
only deletion presents a system dialog. Under limited access, if PhotoKit refuses the album write,
the archive list still records the verdict and the album catches up when access widens (ADR-010).

---

## 7. Persistence

| Data | Lives in | Keyed by | Survives reinstall | Cleared by |
|---|---|---|---|---|
| Trash list | app-local store | `localIdentifier`, `trashedAt` | no | restore, purge |
| Archive list | app-local store | `localIdentifier`, `archivedAt` | no — but recoverable from the album | move, trash |
| Archive album identifier | app-local store | the album's `localIdentifier` | no — re-found by title | — |
| Favorite | Photos | — | yes | the user, in either app |
| Acknowledged selection count | app-local store | — | no | access becomes authorized |
| Rewind entry | memory | — | no | cold launch, cap, invalidation ([§5](#5-queue-lifecycle)) |
| Authorization | the system | — | yes | the user, in Settings |

**What is deliberately not stored.** No "onboarding seen" flag: Permission appears whenever the
authorization status makes it necessary and never otherwise. No per-screenshot "reviewed" flag:
derived ([§1](#1-object-model)). No "waiting" flag and no schedule for when a screenshot comes due:
derived from `creationDate` (ADR-032). No copy of the favorite flag. No session log, no statistics.

**Recovery after reinstall.** The trash list is gone, and because nothing was deleted from Photos
the trashed screenshots simply return to the queue (a recent one waits until it is 30 days old).
The archive list is gone too, but the album is not: on first launch with an empty store, if an
album titled `Brand.archiveAlbumTitle` exists, the app adopts it and seeds the archive list from its
members (A4).

**Mechanism.** Which store (a `Codable` file in Application Support, or SwiftData) is an
architecture decision for the app phase. The IA only requires that the two lists and two scalars
above persist across launches and are read before the queue is computed.

---

## 8. External change

The app observes the library through `PHPhotoLibraryChangeObserver` and reconciles on every change
and on every return to the foreground. Because the queue is derived, most edits made in Photos
need no special case; the table lists the ones that produce a visible effect.

| Change made in Photos | Effect in the app |
|---|---|
| A screenshot is deleted | dropped from the queue and from both lists silently; if it was the front card, the deck promotes without a verdict |
| A screenshot is taken | waits 30 days ([§1](#1-object-model) rule 2): `total` rises at once, the counter does not; `noScreenshots` becomes `allDone`, whose copy names the day it comes due. At the first refresh after it comes due it joins the queue by date, behind the front card |
| A screenshot is hearted | leaves the queue; appears in Library › Favorites |
| A heart is removed | returns to the queue unless it is in the trash or archive list |
| A screenshot is removed from the archive album by hand | treated as un-archiving: the archive entry is dropped and the screenshot returns to the queue |
| The archive album is deleted | the list is the truth: the album is recreated and repopulated on the next archive or launch (A4) |
| The limited selection changes | the interstitial shows on the next return to the foreground (A2) |
| Authorization is revoked | Permission · denied; the stack is discarded |
| Authorization is widened from limited to full | Review; the acknowledged selection count is cleared |

"Returns to the queue" in the rows above means "becomes unreviewed": a screenshot under 30 days old
waits instead, and joins at the first refresh after it comes of age (ADR-032).

Ordering under the thumb never changes: a screenshot that arrives, leaves, changes membership or
comes due mid-drag is applied behind the pinned front card; the front card itself changes only at
the next `promoting`.

---

## 9. System surfaces

Surfaces the app presents but does not design. Their copy and styling are iOS's; the app decides
only when to present them and what to do with each outcome.

| Surface | Presented by | Outcomes the app handles |
|---|---|---|
| Photo-library access dialog | `PHPhotoLibrary.requestAuthorization(for: .readWrite)` on the Permission CTA, never on launch | authorized → Review · limited → interstitial · denied → denied state |
| Limited-library picker | `presentLimitedLibraryPicker(from:)` on "Pick more" | on dismiss, the selection count is re-read and the interstitial updates |
| Delete confirmation | `PHPhotoLibrary.performChanges` with `deleteAssets` — one dialog per call, so "all" is one batch | confirmed → cells removed, `purgeDone`; cancelled → "Not deleted" toast, nothing changes; partial failure → inline "Couldn't delete N. Try again." |
| Settings | `UIApplication.openSettingsURLString` on "Open Settings" | re-routed on the next `scenePhase == .active` |

Favorite and album writes go through `performChanges` too but present nothing.

---

## 10. Assumptions, confirmed

Structural choices this document had to make that no earlier ADR settled. The owner confirmed all
four on 2026-09-27; they are recorded as ADR-025, status Active. Each is written up as a rule above;
the alternative each one displaced is kept here for the record.

| # | Decision | Where it bites | The alternative it displaced |
|---|---|---|---|
| A1 | A screenshot hearted in Photos before the app ever saw it counts as reviewed: it is a Favorite and never enters the queue | [§1](#1-object-model) rule 1; the queue is shorter on first launch | treat only app-set hearts as verdicts, which needs an app-side "seen" set and makes FAVE a no-op on an already-hearted card |
| A2 | The limited interstitial shows on first grant and whenever the selected count differs from the one last acknowledged; otherwise limited access goes straight to Review | [§4](#4-launch-routing), [§8](#8-external-change) | show it on every launch under limited access |
| A3 | The Credits screen is reached from the Library footer once access is granted (the Permission screen's own link was removed by the owner on 2026-09-27) | [§2](#2-screen-inventory) row C | a header overflow menu on Review, or the Settings bundle |
| A4 | The archive **list** is the truth and the album mirrors it: a deleted album is recreated, a hand-removed member is un-archived, an empty store adopts an existing album | [§7](#7-persistence), [§8](#8-external-change) | the album is the truth (`UI_DESIGN.md` §11.4 as written), which loses every archive verdict if the user deletes the album |

Open and not assumed: whether the Review card offers pinch-to-zoom. `UI_DESIGN.md` gives zoom to
the Viewer only; the card is the screenshot at card size.

---

## 11. Out of scope for v1

Search and text filters, a Settings screen, statistics and streaks, multi-select in Trash
(ADR-015), deep links, widgets and Shortcuts, an iPad layout, syncing the app-local lists through
iCloud, reviewing photos that are not screenshots, and any AI assistance.
