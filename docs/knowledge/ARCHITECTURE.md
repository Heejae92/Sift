# Sift · Architecture

v1.5 · 2026-09-29 · English · companion to `IA.md` (what exists) and `UI_DESIGN.md` (what it looks like)

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
| Notifications | UserNotifications directly: one local request, no push | The reminder of ADR-034 needs no server and no background work; iOS keeps and fires it |
| Persistence | One `Codable` JSON file in Application Support | Two lists and two scalars (IA §7); a database would be schema and migration cost for four fields |
| Dependencies | None | Everything the app needs ships in the SDK; a course project should not inherit a dependency's release cycle |
| Project | XcodeGen `project.yml`; the `.xcodeproj` is generated and git-ignored | Same convention as the previous app; merges never touch a pbxproj |
| Fonts | Pretendard Regular/Medium/SemiBold/Bold bundled (SIL OFL); the display face is not bundled | ADR-003: Forager is web-only until an app license exists, `DSFont.resolvedDisplay` falls back to Pretendard Bold |

## 1. Module map

```
Sift/                              app target sources (XcodeGen `sources: [Sift]`)
  SiftApp.swift                    @main · builds the Catalog and the reminder scheduler · pins .light (P-16)
  Navigation/
    RootView.swift                 authorization gate vs the NavigationStack · re-routes on scenePhase ·
                                   hands the reminder scheduler to Review
    Route.swift                    .trash · .library · .credits · viewer presentation
  Data/                            value types and the single source of truth
    Screenshot.swift               Screenshot (id = PHAsset.localIdentifier, creationDate, size, isFavorite)
    Verdict.swift                  Verdict .trash / .archive / .fave · LibrarySegment · RewindEntry
    LocalStore.swift               StoreState (Codable, versioned) · StorePersistence protocol · file + memory impls
    ReviewPolicy.swift             the 30-day rule (ADR-032): minimumAgeDays · minimumAge · the simulator-only override
    ReminderPolicy.swift           the reminder's rule (ADR-034): intervalDays · interval · nextDate · the simulator-only override
    Catalog.swift                  @MainActor @Observable · memberships → queue/waiting/trash/favorites/archived · every write
  Services/                        the world outside the process, behind protocols
    PhotoLibrary.swift             PhotoLibrary protocol · PhotoAuthorization · PhotoLibraryError
    PhotoKitLibrary.swift          the PhotoKit implementation (fetch, observe, favorite, album mirror, delete)
    ReminderScheduler.swift        ReminderScheduler protocol · ReminderStatus · the UserNotifications implementation
    ImageLoader.swift              PHCachingImageManager wrapper · thumbnails and card images · file size
    SystemUI.swift                 open Settings · present the limited-library picker
  Features/                        one folder per screen, screen = view + model
    Permission/                    PermissionScreen (onboarding + denied) · SwipeLegend · DemoStack · LimitedInterstitial
    Review/                        ReviewScreen (+ AllDoneBurst) · ReviewModel (deck state machine, the reminder's status)
                                   CardStack (+ DeckMotion, CardPose, CardSkeleton) · ScreenshotCard · VerdictStamp
                                   VerdictButtonRow (+ VerdictCaption) · RewindButton · ProgressCounter
    Trash/                         TrashScreen · TrashModel · PurgeAllSheet
    Library/                       LibraryScreen · LibraryModel · SegmentedControl
    Viewer/                        AssetViewer (two action sets, chosen by the presenting screen)
    Credits/                       CreditsScreen (DSIconCredits.entries)
  Components/                      cross-screen pieces: DSButton · BlockView · EmptyState · ThumbnailCell · Toast
                                   SwipeGeometry (pure gesture maths, shared by Review and the Permission demo)
  DesignSystem/                    the nine token files: the only place a design value is typed. A product rule's
                                   constant lives in Data/ under the ADR that set it (ReviewPolicy, ADR-032;
                                   ReminderPolicy, ADR-034)
  Resources/
    Assets.xcassets                LaunchBackground · AccentColor · icon catalog (Noun Project assets, when they land)
    Fonts/                         Pretendard-*.otf · Pretendard-OFL.txt (SIL OFL 1.1, ships in the bundle)
    SampleScreenshots/             six real iOS screens (captured by SiftUITests/SampleCaptureTests) for DemoStack and for seeding a simulator
  PrivacyInfo.xcprivacy            no tracking, no collected data, no required-reason APIs
SiftTests/                         Swift Testing · runs on the simulator against FakePhotoLibrary and FakeReminderScheduler ·
                                   SampleSeedTests (opt-in seed tool)
SiftUITests/                       XCTest UI tests: SiftTourTests (the screenshot tour) · SampleCaptureTests (opt-in capture tool) · DemoVideoTests (opt-in demo run)
project.yml                        targets Sift, SiftTests, SiftUITests · scheme Sift
```

Beside the app target, the repository root holds three hand-written pages that GitHub Pages serves:
`design-system.html` (the guide), `ia.html` (the diagrams) and `simulator.html` (the app simulated
in a browser, ADR-035, with its six images in `docs/simulator/`). None of them is built from the
Swift sources. What ties them to the app is the generated `:root` block: `lint` fails when the copy
in the guide or in the simulator is stale. A change to a screen's behaviour is made in the app and
then, by hand, in `simulator.html`.

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
   `queue`, `waiting`, `trashed`, `favorites`, `archived`. Nothing else caches those.
2. **Writes.** A user action calls one `Catalog` method (`trash`, `archive`, `favorite`, `rewind`,
   `restore`, `move`, `trashFromLibrary`, `purge`). The method updates `state`, persists it, and
   performs the matching Photos write through the `PhotoLibrary` protocol. The derived lists change
   as a consequence; the screens re-render.
3. **External change.** `PhotoLibrary.changes()` yields whenever Photos changes. The `Catalog`
   re-fetches and reconciles (IA §8). The `ReviewModel` decides *how* a reconcile reaches the deck:
   during `dragging` and `exiting` the front card stays pinned and only the cards behind it refresh;
   the front card itself changes only at the next `promoting` (IA §5, §8).
4. **The reminder** (ADR-034) stays outside the catalog. `ReviewModel` reads it through
   `ReminderScheduler` when the all-done block appears and on every return to the foreground, turns
   it on from the block, and re-anchors it when the queue runs out under review. iOS keeps the only
   copy, the pending notification request; nothing reaches `StoreState`.

## 3. The catalog: one source of truth

`Catalog` is `@MainActor @Observable`. Its invariants are the IA's rules, stated as code:

| Derived | Definition |
|---|---|
| `queue` | screenshots not in `state.trash`, not in `state.archive`, not `isFavorite` (unreviewed), and due: `creationDate` at least `minimumAge` before `referenceDate`, the boundary included; newest first |
| `waiting` | unreviewed and not due yet; oldest first |
| `nextArrival` | the first waiting screenshot's `creationDate + minimumAge`; `nil` when none waits |
| `trashed` | screenshots in `state.trash`; most recently trashed first |
| `favorites` | `isFavorite` and not in `state.trash` |
| `archived` | in `state.archive` and not in `state.trash` |
| `total` | every screenshot the app can see, due or not; the limited-access interstitial and its selection check count these |
| `reviewTotal` | the due screenshots, reviewed or not: the counter's denominator |
| `reviewedCount` | `reviewTotal - queue.count` |

`referenceDate` is stored, not derived: `now()` at init and at the start of every `refresh()`, so
the queue holds still between refreshes and a screenshot comes due on the next one — a change in
Photos, a launch, or a return to the foreground (`RootView` → `refreshAuthorization()`). The age
rule (ADR-032) touches the queue only; `minimumAge` is injected, defaulting to
`ReviewPolicy.minimumAge`, and nothing about it is persisted.

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

`ReminderScheduler` (ADR-034) is the second service protocol, built the same way: `Sendable`, async
only, no UserNotifications type in a signature, with `UserNotificationsReminderScheduler` behind it and
`actor FakeReminderScheduler` in the tests. The reminder is one request, `sift.reminder`, with a
repeating `UNTimeIntervalNotificationTrigger` of `ReminderPolicy.interval`.

| Method | UserNotifications behind it | Notes |
|---|---|---|
| `status()` | `notificationSettings()` and `pendingNotificationRequests()` | read-only, never asks; the mapping is the pure `UserNotificationsReminderScheduler.status(authorization:alert:lockScreen:notificationCenter:pendingInterval:userInfo:now:)`, tested in `ReminderStatusTests`. `.denied` when declined, and when allowed with alerts, the lock screen and Notification Center all off; `.off` when undetermined or nothing is pending; otherwise `.on(next:)`. `next` is `ReminderPolicy.nextDate` from the moment the request was added, which it carries in `userInfo`, because the trigger's `nextTriggerDate()` answers "now + interval" at every reading. A request without that moment, or with something else under its key, reports now + interval, which is all iOS would say; that case is unreachable, because the app writes the moment on every request |
| `enable()` | `requestAuthorization(options: [.alert, .sound])` while `.notDetermined`, then `add` | on the all-done block's tap only (ADR-010); returns the status read afterwards |
| `reanchor()` | `add` with the same identifier, which replaces the pending request | only while `.on`; called when the queue runs out under review |

`ImageLoader` wraps `PHCachingImageManager` on the main actor: `image(for:targetSize:)` returns one
`UIImage?` (high-quality format, network allowed), plus `startCaching`/`stopCaching` for the grid.
`SystemUI` holds the UIKit escapes: `openSettings()`, the app's page in Settings, for the denied
Permission block; `openNotificationSettings()`, the app's notification settings
(`UIApplication.openNotificationSettingsURLString`), for "Turn on reminders in Settings"; and
`presentLimitedLibraryPicker()`.

## 5. Feature models and the deck state machine

Each screen has a thin model that reads the catalog and owns only screen-local state:

- `ReviewModel` — the state machine of IA §5. `Phase` is an enum with every case designed:
  `loading`, `reviewing`, `dragging`, `exiting(Verdict)`, `promoting`, `rewinding`, `allDone`,
  `noScreenshots`. The front card is stable (IA §5): `deck` is recomputed from `catalog.queue` on
  every change, but while reviewing the current front stays in front and a newcomer joins behind it;
  only a verdict, a rewind or the card's own disappearance changes it. A screenshot that comes due
  is such a newcomer, and the newest due one, so the rule is what keeps it from landing under the
  thumb; `ReviewScreen` calls `catalogDidChange()` on `catalog.referenceDate` as well, because a
  refresh of an unchanged library changes nothing else. `noScreenshots` means `catalog.total == 0`;
  a library whose screenshots are all waiting is `allDone`, and the counter's `total` is
  `catalog.reviewTotal`. `commit(_:exitDuration:)` runs
  the exit, sleeps `DSSwipe.promoteAt × duration`, then applies the side effect and promotes;
  `rewind()` replays the recorded entry, and `catalogDidChange()` drops that entry when its verdict
  no longer stands (restored in Trash, purged, un-hearted in Photos). The sleep is injected so tests
  run without waiting. The model also carries the all-done block's reminder (ADR-034): `reminder`, a
  `ReminderStatus?` that is nil until read, and `reminderOnCount`, the grant haptic's trigger.
  `sync()` starts `reminders.reanchor()` at the moment it increments `queueDoneCount`;
  `refreshReminder()` waits for that re-anchor, so it reads the new date, and is skipped while
  `enableReminder()` waits on iOS, whose permission prompt takes the scene through inactive and back.
  A refresh whose read was already out when "Remind me" started is dropped: `enableReminder()` moves
  a generation counter, and the refresh assigns only if it has not moved. `enableReminder()` also
  sets `lastAnnouncement` to the outcome, "Reminder on. Next reminder: Oct 29." or "Notifications are
  off. Turn on reminders in Settings.", because the action VoiceOver was on goes away (P-22).
  The scheduler is injected like the photo library: `SiftApp` builds it and `RootView` hands it to
  `ReviewScreen`, which passes it to the model.
- `SwipeGeometry` (in `Components/`, because the Permission demo swipes too) — pure functions for
  the gesture: sector from `(dx, dy)` with hysteresis, the commit rule (distance or velocity with a
  travel floor), rotation, stamp opacity, all read from `DSSwipe`. Tested on their own.
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
later schema can migrate instead of guess. The reminder adds nothing here: iOS keeps the pending
request, and the moment it was added rides inside it (ADR-034).

## 7. Concurrency rules

- `Catalog`, every feature model, `ImageLoader` and every view are **`@MainActor`**.
- `PhotoLibrary` is **`Sendable`** and every method is `async`. PhotoKit work that is synchronous
  and slow (`fetchAssets` + enumeration) runs in `Task.detached` and returns `Sendable` value types;
  no `PHAsset` crosses an isolation boundary.
- Mutations go through `PHPhotoLibrary.shared().performChanges { }` with only `String` identifiers
  captured; assets are re-fetched inside the block.
- `ReminderScheduler` is `Sendable` and async the same way. `UserNotificationsReminderScheduler` has no
  stored state and asks `UNUserNotificationCenter.current()` in each call; settings, requests and
  triggers stay inside the call, and only `ReminderStatus` values leave it.
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
revocation discards the path and shows the denied state. On the same event `ReviewScreen` re-reads
the reminder while the all-done block is up (ADR-034). A tap on a delivered reminder only opens the
app: there is no notification delegate and no route for it.

## 9. Testing

Two test targets run on the simulator, both hosted by the app `Sift`.

**`SiftTests`**, Swift Testing, covers everything that is not a view:

| Suite | What it proves |
|---|---|
| `CatalogTests` | the five derived lists (`queue`, `waiting`, `trashed`, `favorites`, `archived`) against `FakePhotoLibrary`; A1 (pre-existing heart skips the queue); every write and its rewind; restore returns by date; move clears the source; purge clears the list; album adoption on an empty store; the 30-day rule: recent screenshots wait outside the queue and the counter's denominator, one ages in on the next refresh, exactly 30 days is due, and a clock set back keeps a due card due |
| `LocalStoreTests` | JSON round trip, missing file, version field |
| `SwipeGeometryTests` | sector boundaries and hysteresis, commit by distance and by velocity with the travel floor, rotation clamp, stamp ramp endpoints |
| `ReviewModelTests` | loading → reviewing / allDone / noScreenshots; commit → promote → next card; single-step rewind; new screenshot joins behind the front card; only waiting screenshots is allDone, not noScreenshots, with no burst; finishing the queue while others wait is a finished queue; a screenshot that comes due joins behind the front card; the reminder (ADR-034): "Remind me" asks once, turns it on and announces the date, a declined prompt is denied, announced and never asked again, a verdict that empties the queue re-anchors it (again after a rewind and a second finish), a partial session and a launch into all-done do not, a finished queue while off or denied schedules and asks nothing, and a refresh can neither answer for "Remind me" while its prompt is up nor undo it afterwards with a read taken before it (the fake holds `enable()` or `status()` at a gate) |
| `ReviewPolicyTests` | `-SiftMinimumAgeDays` counts only as a whole number of days, 0 or more |
| `ReminderPolicyTests` | `-SiftReminderSeconds` counts only as a whole number of seconds, 60 or more; `nextDate` counts whole intervals from the moment the request was added, a clock set back included |
| `ReminderStatusTests` | the UserNotifications status mapping as a pure function: authorization first; allowed with every place switched off is denied, one place on is enough; the pending request decides between off and on, dated from its `userInfo` moment, a number as iOS returns it; a missing or malformed moment reports now + interval |
| `ReviewPresentationTests` | the all-done body lines, including the reminder's date line in place of the next screenshot's; the all-done actions for each reminder state beside "Open Trash (N)"; the header counter's mapping; all as pure functions |
| `LimitedInterstitialTests` | the limited-access copy: nothing waiting as before; some ready, the CTA counting them and no date; none ready, the day ("It's ready" when one waits) and "Continue"; nothing picked a screenshot, "Pick more" filled and "Continue" as text; singular and plural (ADR-033) |
| `SampleSeedTests` | not a test: the opt-in seed tool below, simulator builds only, skipped unless `SIFT_SEED_SAMPLES=1` |

Clocks: every `CatalogTests` catalog is built by `make()` on a `TickingClock`, which starts 90 days
after the 2023 fixtures, except the boundary test, which pins a fixed reference date.
`ReviewModelTests` runs on the wall clock (2026) against the same 2023 fixtures, which are therefore
due, except its four ADR-032 tests, which pass a `TickingClock` so a screenshot can age in. Every
test catalog is given the 30-day rule explicitly (`Fixtures.minimumAge`) rather than reading
`ReviewPolicy.minimumAge`: the Test action runs the host app with the Run action's arguments, so a
local scheme edit adding `-SiftMinimumAgeDays` would otherwise change what the tests check. The fake
reminder scheduler takes the owner's 30 days the same way (`FakeReminderScheduler.interval`), not
`ReminderPolicy.interval`, which honours `-SiftReminderSeconds`, and keeps its own clock, moved on
with `advance(by:)`. Of the UserNotifications implementation, the status mapping is unit-tested as a
pure function (`ReminderStatusTests`); the calls into the notification center were checked on the
simulator (ADR-034).

**`SiftUITests`**, XCTest, drives the real app and is a smoke test with pictures, not a spec:

- `SiftTourTests` is the screenshot tour. It launches with `-SiftAllImages`, grants photo access
  through the system dialog on a fresh install, walks Permission, Review, Trash, the viewer, the
  purge sheet, Library and Credits, and attaches a screenshot at each stop (`docs/DEVELOPMENT.md`
  "Running on the simulator").
- `SampleCaptureTests` is a development tool, not a test of the app: it captures the six sample
  screenshots from the simulator's built-in apps. It is skipped unless `SIFT_CAPTURE_SAMPLES=1` is in
  the runner's environment, passed on the `xcodebuild` line as `TEST_RUNNER_SIFT_CAPTURE_SAMPLES=1`.
- `DemoVideoTests` is the other development tool of that kind: a paced run through Permission, Review
  (three swipes, a rewind, the rest of the deck), the all-done block, Trash (its Delete-all sheet is
  answered with Keep, so nothing is deleted) and Library, which `simctl io recordVideo` films and
  `scripts/make-demo-video.swift` turns into the video on the project page (`docs/demo/`). It
  launches with no launch arguments, so it sees the real 30-day rule (ADR-032). It is skipped unless
  `SIFT_RECORD_DEMO=1` is in the runner's environment, passed as `TEST_RUNNER_SIFT_RECORD_DEMO=1`.
  It is filmed with `simctl io recordVideo` and depends on the seeded simulator library. It
  archives, favorites and trashes the seeded samples, so a second take starts from an unreviewed
  library (`docs/DEVELOPMENT.md` "Recording the demo").

All three change what they run on. The tour and the demo answer the photo-access dialog with Allow
Full Access and archive and favorite through the app, which writes to Photos, and on a device that
library is someone's own photos; the capture tool answers the built-in apps' permission alerts, which
on a device belong to someone's own apps. So each calls `super.setUpWithError()` and then, when it is
not built for a simulator (`#if !targetEnvironment(simulator)`, ADR-035's corrections of
2026-09-29), throws an `XCTSkip` that says what it would change: "simulator only: grants photo
access, archives and favorites in Photos" for the tour and the demo, "simulator only: answers other
apps' permission alerts" for the capture tool. They hold no PhotoKit code, so a device test build
still compiles them and the gate acts at run time, before their first step. `SampleSeedTests`, below,
is gated at compile time instead.

Their companion lives in `SiftTests`, because it needs the app's own Photos access rather than a UI:

- `SampleSeedTests` is the other development tool (ADR-033): it adds the six bundled samples to the
  simulator's Photos library with fixed creation dates in August 2026, 35 to 58 days before
  2026-09-28, so Review has real screenshots that are due. It compiles into simulator builds only
  (`#if targetEnvironment(simulator)`), so a test build for a device does not contain it. It is
  disabled unless `SIFT_SEED_SAMPLES=1` is in the test process's environment, which `xcodebuild`
  passes on from its own environment as `TEST_RUNNER_SIFT_SEED_SAMPLES=1`; it fails with a message
  when the app lacks full access, and a second run adds nothing. Access has to come first: on a fresh
  or erased simulator the order is `simctl addmedia`, grant access, the seed tool, then the tour
  (`docs/DEVELOPMENT.md` "Running on the simulator").

Views are verified on the simulator with the design system's checklist and the tour's pictures, not
by unit tests. The limited-access interstitial is outside the tour, which runs with full access: its
look was checked once, in a manual render on 2026-09-28 that nothing in the repository repeats, and
real limited access has not been exercised.

## 10. Build and verify

```
xcodegen generate                                                   # writes Sift.xcodeproj (ignored)
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SiftTests test
xcodebuild -scheme Sift -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SiftUITests/SiftTourTests -resultBundlePath /tmp/sift-tour.xcresult test   # the tour
```

The unit tests are the plain test command. The tour is its own command because it needs a seeded,
granted simulator and changes the app's data there (`docs/DEVELOPMENT.md` "Running on the
simulator").

Run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on this machine
(`xcode-select` points at the command-line tools). The four design-system commands (P-23) are
unchanged and still gate any token edit.

**Simulator overrides.** Three launch arguments exist for a simulator and are read only under
`#if DEBUG && targetEnvironment(simulator)`, so a release build and every build for a device ignore
them:

| Argument | Read in | Effect |
|---|---|---|
| `-SiftAllImages` | `PhotoKitLibrary.reviewAllImages` | drops the screenshot predicate and reviews every image (ADR-027); the `Sift` scheme passes it on Run |
| `-SiftMinimumAgeDays <n>` | `ReviewPolicy.minimumAge` | reviews screenshots at least `n` days old instead of 30 (ADR-032); not in the scheme, so a simulator shows the real rule unless it is added under Edit Scheme → Run → Arguments |
| `-SiftReminderSeconds <n>` | `ReminderPolicy.interval` | schedules the reminder every `n` seconds, 60 or more, instead of every 30 days (ADR-034); not in the scheme. A pending reminder keeps the interval it was added with until it is re-anchored |

The Test action uses the Run action's arguments, so all three reach the unit-test host too; the
tests are written not to depend on any of them (§9).

## 11. Build order

| # | Step | Done when |
|---|---|---|
| A | Scaffold: `project.yml`, app entry, `Data/`, `Services/`, placeholder screens, tests | `xcodebuild build` and `test` are green |
| B | Review: deck, stamps, buttons, rewind, counter, empty states | the swipe demo in `design-system.html` and the app behave identically |
| C | Permission, Trash, Library, Viewer, Credits | every state in `UI_DESIGN.md` §11 renders |
| D | Simulator run with seeded screenshots; VoiceOver and Reduce Motion pass | the P-19 to P-22 checklist lines are ticked |
