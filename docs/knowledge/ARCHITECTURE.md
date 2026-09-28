# Sift · Architecture

v1.0 · 2026-09-27 · English · companion to `IA.md` (what exists) and `UI_DESIGN.md` (what it looks like)

This file is the map of the code: which modules exist, what each one owns, how data moves, and
what a change has to touch. Read it before adding a file; update it when you add one. Decisions
with a reason that could be questioned later are in `DECISIONS.md` (ADR-026 onward for the app).

## Contents

- [0. Stack and constraints](#0-stack-and-constraints)
- [1. Module map](#1-module-map)
- [2. Data flow](#2-data-flow)
- [3. The catalog: one source of truth](#3-the-catalog-one-source-of-truth)
- [4. Services](#4-services)
- [5. Feature models and the deck state machine](#5-feature-models-and-the-deck-state-machine)
- [6. Persistence](#6-persistence)
- [7. Concurrency rules](#7-concurrency-rules)
- [8. Navigation](#8-navigation)
- [9. Testing](#9-testing)
- [10. Build and verify](#10-build-and-verify)
- [11. Build order](#11-build-order)

---

## 0. Stack and constraints

| | Choice | Why |
|---|---|---|
| Platform | iOS 17.0+, iPhone only, portrait | The IA needs `.sensoryFeedback`, `@Observable`, `Font.custom(_:fixedSize:)`; the deck is a one-hand phone interaction |
| Language | Swift 6 language mode, strict concurrency | The token files already type-check in mode 6; PhotoKit callbacks are the one place isolation has to be thought about, and the compiler is the cheapest reviewer |
| UI | SwiftUI, Observation (`@Observable`), no UIKit views | One toolkit; UIKit appears only where the system forces it (the limited-library picker takes a `UIViewController`) |
| Photos | PhotoKit directly | The app *is* a PhotoKit client; no wrapper library pays for itself |
| Persistence | One `Codable` JSON file in Application Support | Two lists and two scalars (IA §7); a database would be schema and migration cost for four fields |
| Dependencies | None | Everything the app needs ships in the SDK; a course project should not inherit a dependency's release cycle |
| Project | XcodeGen `project.yml`; the `.xcodeproj` is generated and git-ignored | Same convention as the previous app; merges never touch a pbxproj |
| Fonts | Pretendard Regular/Medium/SemiBold/Bold bundled (SIL OFL); the display face is not bundled | ADR-003: Forager is web-only until an app license exists, `DSFont.resolvedDisplay` falls back to Pretendard Bold |

## 1. Module map

```
Sift/                              app target sources (XcodeGen `sources: [Sift]`)
  SiftApp.swift                    @main · builds the Catalog · pins .light (P-16)
  Navigation/
    RootView.swift                 authorization gate vs the NavigationStack · re-routes on scenePhase
    Route.swift                    .trash · .library · .credits · viewer presentation
  Data/                            value types and the single source of truth
    Screenshot.swift               Screenshot (id = PHAsset.localIdentifier, creationDate, size, isFavorite)
    Verdict.swift                  Verdict .trash / .archive / .fave · LibrarySegment · RewindEntry
    LocalStore.swift               StoreState (Codable, versioned) · StorePersistence protocol · file + memory impls
    Catalog.swift                  @MainActor @Observable · memberships → queue/trash/favorites/archived · every write
  Services/                        the world outside the process, behind protocols
    PhotoLibrary.swift             PhotoLibrary protocol · PhotoAuthorization · PhotoLibraryError
    PhotoKitLibrary.swift          the PhotoKit implementation (fetch, observe, favorite, album mirror, delete)
    ImageLoader.swift              PHCachingImageManager wrapper · thumbnails and card images · file size
    SystemUI.swift                 open Settings · present the limited-library picker
  Features/                        one folder per screen, screen = view + model
    Permission/                    PermissionScreen · SwipeLegend · DemoStack · LimitedInterstitial · DeniedView
    Review/                        ReviewScreen · ReviewModel (deck state machine) · SwipeGeometry
                                   CardStack · ScreenshotCard · VerdictStamp · VerdictButtonRow · RewindButton · ProgressCounter
    Trash/                         TrashScreen · TrashModel · PurgeAllSheet
    Library/                       LibraryScreen · LibraryModel · SegmentedControl
    Viewer/                        AssetViewer (two action sets, chosen by the presenting screen)
    Credits/                       CreditsScreen (DSIconCredits.entries)
  Components/                      cross-screen pieces: Buttons · ThumbnailCell · EmptyState · BlockView · Toast
  DesignSystem/                    the nine token files. Unchanged by the app phase; the only place a value is typed
  Resources/
    Assets.xcassets                LaunchBackground · AccentColor · icon catalog (Noun Project assets, when they land)
    Fonts/                         Pretendard-*.otf
    SampleScreenshots/             six PNGs for DemoStack and for seeding a simulator
  PrivacyInfo.xcprivacy            no tracking, no collected data, no required-reason APIs
SiftTests/                         Swift Testing · runs on the simulator against FakePhotoLibrary
project.yml                        targets Sift, SiftTests · scheme Sift
```

Rules of the map:

- **A feature folder owns its screen and its model, nothing else.** A view in `Features/Trash` may
  use anything in `Components/` and `DesignSystem/`; it never imports a type from
  `Features/Review`. Shared behaviour goes down into `Components/` or `Data/`, not sideways.
- **`Data/` and `Services/` import no SwiftUI.** They are testable without a screen.
- **`DesignSystem/` is read-only for the app phase** (P-12). A missing token is added there, then
  the four verification commands run (P-23).

## 2. Data flow

```
PhotoKit ──changes()──▶ PhotoKitLibrary ──[Screenshot]──▶ Catalog ──derived lists──▶ feature models ──▶ views
                                                            ▲                              │
              StoreState (JSON) ◀── persistence ◀── writes ─┘ ◀──── user actions ──────────┘
```

One direction for reads, one for writes:

1. **Reads.** The `Catalog` owns the only copy of `screenshots` (everything the app can see, newest
   first) and `state` (the two lists and two scalars). Every screen reads a *derived* list off it:
   `queue`, `trashed`, `favorites`, `archived`. Nothing else caches those.
2. **Writes.** A user action calls one `Catalog` method (`trash`, `archive`, `favorite`, `rewind`,
   `restore`, `move`, `trashFromLibrary`, `purge`). The method updates `state`, persists it, and
   performs the matching Photos write through the `PhotoLibrary` protocol. The derived lists change
   as a consequence; the screens re-render.
3. **External change.** `PhotoLibrary.changes()` yields whenever Photos changes. The `Catalog`
   re-fetches and reconciles (IA §8). The `ReviewModel` decides *when* a reconcile reaches the deck:
   never during `dragging` or `exiting`, always at the next `promoting` (IA §5).

## 3. The catalog: one source of truth

`Catalog` is `@MainActor @Observable`. Its invariants are the IA's rules, stated as code:

| Derived | Definition |
|---|---|
| `queue` | screenshots not in `state.trash`, not in `state.archive`, not `isFavorite`; newest first |
| `trashed` | screenshots in `state.trash`; most recently trashed first |
| `favorites` | `isFavorite` and not in `state.trash` |
| `archived` | in `state.archive` and not in `state.trash` |
| `reviewedCount` | `total - queue.count` |

Membership precedence on display is Trash > everything (IA §1 rule 3). A pre-existing heart is a
Favorite and never enters the queue (A1). The archive **list** is the truth and the album is its
mirror (A4): `ensureArchiveAlbum` recreates a missing album; on an empty store with an existing
album of the right title, `adoptArchiveAlbumIfNeeded` seeds the list from its members.

Every write returns what rewind needs. `RewindEntry` records the screenshot, the verdict and the
flags that were true before it, so `rewind(_:)` restores exactly that and nothing more (ADR-008).

## 4. Services

`PhotoLibrary` is a `Sendable` protocol with async methods only, so the PhotoKit implementation and
the test fake (`actor FakePhotoLibrary`) are interchangeable:

| Method | PhotoKit behind it | Notes |
|---|---|---|
| `authorizationStatus()` / `requestAuthorization()` | `PHPhotoLibrary.authorizationStatus(for: .readWrite)` / `requestAuthorization(for:)` | requested on tap only (ADR-010) |
| `fetchScreenshots()` | `PHAsset.fetchAssets(with: .image)` filtered by `mediaSubtypes & photoScreenshot`, sorted by `creationDate` desc | the predicate form works under limited access, where smart albums are unreliable |
| `changes()` | `PHPhotoLibraryChangeObserver` → `AsyncStream<Void>` | the observer is a `Sendable` NSObject; the catalog re-fetches on every yield. Opened only once access is usable: registering with PhotoKit prompts while access is undetermined, and ADR-010 puts the prompt on the Permission tap, never on launch |
| `setFavorite(_:_:)` | `PHAssetChangeRequest(for:).isFavorite` | no system dialog |
| `ensureArchiveAlbum(existingID:title:)` | fetch by id, then by title, else `creationRequestForAssetCollection` | returns the album `localIdentifier` |
| `albumMembers(albumID:)` / `addToAlbum` / `removeFromAlbum` | `PHAssetCollectionChangeRequest` | the mirror; failures under limited access are swallowed into `PhotoLibraryError.albumWriteRefused` and the list stays the truth |
| `delete(_:)` | `PHAssetChangeRequest.deleteAssets` | one system dialog per call; `userCancelled` → `PhotoLibraryError.cancelled` |
| `fileSizeBytes(for:)` | `PHAssetResource.assetResources(for:)` | prefetched three cards ahead; may be nil |

`ImageLoader` wraps `PHCachingImageManager` on the main actor: `image(for:targetSize:)` returns one
`UIImage?` (high-quality format, network allowed), plus `startCaching`/`stopCaching` for the grid.
`SystemUI` holds the two UIKit escapes: `openSettings()` and `presentLimitedLibraryPicker()`.

## 5. Feature models and the deck state machine

Each screen has a thin model that reads the catalog and owns only screen-local state:

- `ReviewModel` — the state machine of IA §5. `Phase` is an enum with every case designed:
  `loading`, `reviewing`, `dragging`, `exiting(Verdict)`, `promoting`, `rewinding`, `allDone`,
  `noScreenshots`. It pins the front card: `deck` is recomputed from `catalog.queue` only when the
  phase allows it. `commit(_:exitDuration:)` runs the exit, sleeps `DSSwipe.promoteAt × duration`,
  then applies the side effect and promotes; `rewind()` replays the recorded entry. The sleep is
  injected so tests run without waiting.
- `SwipeGeometry` — pure functions for the gesture: sector from `(dx, dy)` with hysteresis, the
  commit rule (distance or velocity with a travel floor), rotation, stamp opacity, all read from
  `DSSwipe`. Tested on their own.
- `TrashModel` — `trashed` plus the purge flow: `purgeOne`, `purgeAll` (sheet → dialog), and the
  outcome surfaced as a toast or an inline line (IA §9).
- `LibraryModel` — `favorites` / `archived`, the segment, and `move` / `trash` from the viewer.
- `PermissionModel` lives inside `RootView`: authorization, the acknowledged selection count, and
  the routing table of IA §4.

## 6. Persistence

`StoreState` is one `Codable` struct: `version`, `trash: [TrashEntry]`, `archive: [ArchiveEntry]`,
`archiveAlbumID`, `acknowledgedSelectionCount`. `FileStorePersistence` writes it atomically to
`Application Support/<bundle>/store.json`; `InMemoryPersistence` backs tests. The catalog loads it
before the first queue is computed and saves after every mutation. A missing file is a fresh install
(IA §7 recovery: trash returns to the queue; the album is adopted by title). `version` exists so a
later schema can migrate instead of guess.

## 7. Concurrency rules

- `Catalog`, every feature model, `ImageLoader` and every view are **`@MainActor`**.
- `PhotoLibrary` is **`Sendable`** and every method is `async`. PhotoKit work that is synchronous
  and slow (`fetchAssets` + enumeration) runs in `Task.detached` and returns `Sendable` value types;
  no `PHAsset` crosses an isolation boundary.
- Mutations go through `PHPhotoLibrary.shared().performChanges { }` with only `String` identifiers
  captured; assets are re-fetched inside the block.
- The change observer is a `Sendable` `NSObject` that yields into an `AsyncStream`; the catalog
  consumes the stream on the main actor. `Catalog.startObserving()` is idempotent and guarded on
  `authorization.isUsable`; `load()`, `requestAuthorization()` and `refreshAuthorization()` call it
  themselves the moment access becomes usable, so no view decides when observing starts.
- No `DispatchQueue`, no `NotificationCenter` for app state, no `@unchecked Sendable` outside the
  one image-request continuation guard.

## 8. Navigation

IA §3, as code. `RootView` switches on `catalog.authorization`:

- `notDetermined`, `denied`, `restricted` → `PermissionScreen` (onboarding or denied state);
- `limited` with a changed selection → the limited interstitial; otherwise → the stack;
- `authorized` → the stack.

The stack is one `NavigationStack` with `Route` values: Review is the root; `.trash` and `.library`
push from the header; `.credits` pushes from Library. `AssetViewer` is a `fullScreenCover`;
`PurgeAllSheet` is a `sheet`. Authorization is re-read on every `scenePhase == .active`; a
revocation discards the path and shows the denied state.

## 9. Testing

Swift Testing on the simulator, host app `Sift`, no UI tests in v1.

| Suite | What it proves |
|---|---|
| `CatalogTests` | the four derived lists against `FakePhotoLibrary`; A1 (pre-existing heart skips the queue); every write and its rewind; restore returns by date; move clears the source; purge clears the list; album adoption on an empty store |
| `LocalStoreTests` | JSON round trip, missing file, version field |
| `SwipeGeometryTests` | sector boundaries and hysteresis, commit by distance and by velocity with the travel floor, rotation clamp, stamp ramp endpoints |
| `ReviewModelTests` | loading → reviewing / allDone / noScreenshots; commit → promote → next card; single-step rewind; new screenshot joins behind the front card |

Views are verified on the simulator with the design system's checklist, not by unit tests.

## 10. Build and verify

```
xcodegen generate                                                   # writes Sift.xcodeproj (ignored)
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on this machine
(`xcode-select` points at the command-line tools). The four design-system commands (P-23) are
unchanged and still gate any token edit.

## 11. Build order

| # | Step | Done when |
|---|---|---|
| A | Scaffold: `project.yml`, app entry, `Data/`, `Services/`, placeholder screens, tests | `xcodebuild build` and `test` are green |
| B | Review: deck, stamps, buttons, rewind, counter, empty states | the swipe demo in `design-system.html` and the app behave identically |
| C | Permission, Trash, Library, Viewer, Credits | every state in `UI_DESIGN.md` §11 renders |
| D | Simulator run with seeded screenshots; VoiceOver and Reduce Motion pass | the P-19 to P-22 checklist lines are ticked |
