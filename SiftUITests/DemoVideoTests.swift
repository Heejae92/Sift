import XCTest

/// A development tool, not a test of Sift: performs the run that `scripts/make-demo-video.swift` turns
/// into the demo video at the top of the project page (`docs/demo/sift-demo.mp4`). It is paced for a
/// viewer, about 70 seconds with no sound, so every step holds long enough to be read: Permission
/// (the demo cards looping, Get started, the photo-access dialog) → Review (three swipes, a rewind, the
/// rest of the deck) → the all-done block → Trash (the grid, the Delete-all sheet, which it answers
/// with Keep) → Library (Favorites, then Archive). Nothing is ever deleted.
///
/// It launches with no launch arguments, so Review asks only about screenshots that are 30 or more
/// days old (ADR-032), the way a real phone does. Skipped unless `SIFT_RECORD_DEMO=1` is in the
/// runner's environment, which `xcodebuild` passes on from its own environment, prefixed. Start the
/// recording first and stop it afterwards; docs/DEVELOPMENT.md ("Recording the demo") has the whole
/// sequence:
///
///     xcrun simctl io <UDID> recordVideo --codec=h264 --mask=black --force raw.mov &
///     TEST_RUNNER_SIFT_RECORD_DEMO=1 xcodebuild … -only-testing:SiftUITests/DemoVideoTests test
///
/// The run changes the library it sifts: the screenshots it archives and favorites stop being cards,
/// and Sift's own Trash list is app data. Start from an uninstalled app (a fresh photo-access
/// dialog and an empty Trash) and a library whose due screenshots are all unreviewed.
@MainActor  // XCUIApplication and its queries are main-actor isolated; XCTest runs the case on the main thread
final class DemoVideoTests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// The three verdicts as a finger draws them from the middle of the card.
    private enum Swipe {
        case left, right, up

        /// Past `DSSwipe.commitDistance` (120 pt), so the stamp is fully in and a release commits.
        var vector: CGVector {
            switch self {
            case .left: return CGVector(dx: -150, dy: 0)
            case .right: return CGVector(dx: 150, dy: 0)
            case .up: return CGVector(dx: 0, dy: -150)
            }
        }
    }

    func testDemoRun() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIFT_RECORD_DEMO"] == "1",
                          "set SIFT_RECORD_DEMO=1 (TEST_RUNNER_SIFT_RECORD_DEMO=1 on xcodebuild) to perform the demo run")
        continueAfterFailure = false  // a run that went wrong is not worth the rest of a minute of video
        app.launch()

        // 1. Permission: the demo cards loop through TRASH, ARCHIVE and FAVE (2.2 s a card), then the
        //    system dialog. A photo-access answer that is already on file skips the dialog.
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 60), "Permission screen did not appear")
        hold(7)
        getStarted.tap()
        let allow = springboard.buttons["Allow Full Access"]
        let reviewHeader = topmost(app.buttons.matching(identifier: "Trash"))
        let dialogDeadline = Date().addingTimeInterval(30)  // a fresh install can take a while to raise it
        while Date() < dialogDeadline, !reviewHeader.exists {
            if allow.exists {
                hold(2.5)  // long enough to read the dialog
                allow.tap()
                break
            }
            usleep(250_000)
        }

        // 2. Review: three swipes, a rewind, then the rest of the deck.
        XCTAssertTrue(reviewHeader.waitForExistence(timeout: 30), "Review header did not appear")
        XCTAssertTrue(frontCard().waitForExistence(timeout: 30), "front card not found")
        hold(1.5)  // let the first cards decode, and the viewer see the screen
        step(3.2) { swipe(.left) }   // TRASH
        step(3.2) { swipe(.right) }  // ARCHIVE
        step(3.2) { swipe(.up) }     // FAVE
        let rewind = app.buttons["Rewind"]
        XCTAssertTrue(rewind.waitForExistence(timeout: 4) && rewind.isEnabled, "Rewind is not available")
        step(2.4) { rewind.tap() }   // the Fave card comes back to the front

        // The card that came back goes to Trash this time, the next is a favorite, then one to Archive,
        // and the last to Trash: Trash holds three, Archive two and Favorites one.
        for verdict in [Swipe.left, .up, .right, .left] {
            step(3.2) { swipe(verdict) }
        }
        // A library with more due screenshots than the plan covers: the rest go to Trash, so the run
        // always ends on the all-done block.
        let openTrash = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Trash'")).firstMatch
        var isAllDone = openTrash.waitForExistence(timeout: 5)
        for _ in 0..<40 where !isAllDone {
            step(1.2) { swipe(.left) }
            isAllDone = openTrash.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(isAllDone, "all-done block did not appear")
        hold(1.5)  // the block has been up since the end of the last swipe already

        // 3. Trash: the grid and its header, then the Delete-all sheet, answered with Keep.
        openTrash.tap()
        let purgeAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete all'")).firstMatch
        XCTAssertTrue(purgeAll.waitForExistence(timeout: 8), "Trash screen did not appear")
        // The header ("Trash · 3 items · 1.2 MB") reads the sizes off Photos after the grid is up.
        let header = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Trash ·'")).firstMatch
        let sizeDeadline = Date().addingTimeInterval(10)
        while Date() < sizeDeadline, !(header.exists && header.label.contains("B")) { usleep(250_000) }
        hold(3.5)
        purgeAll.tap()
        let keep = app.buttons["Keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 6), "Delete-all sheet did not appear")
        hold(3.5)
        keep.tap()  // never "Delete N": the demo deletes nothing
        hold(1.5)
        goBack()
        hold(1.2)

        // 4. Library: Favorites, then Archive.
        app.buttons["Library"].tap()
        let archiveSegment = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Archive'")).firstMatch
        XCTAssertTrue(archiveSegment.waitForExistence(timeout: 8), "Library did not appear")
        hold(3.5)
        archiveSegment.tap()
        hold(4)
    }

    // MARK: - Helpers

    /// Sleeps on purpose: the pauses are the pacing.
    private func hold(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Runs `action`, then waits out what is left of `seconds`, counted from before the action: a slow
    /// machine stretches the gesture, not the pause after it.
    private func step(_ seconds: TimeInterval, _ action: () -> Void) {
        let began = Date()
        action()
        hold(max(0, seconds - Date().timeIntervalSince(began)))
    }

    private func frontCard() -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Screenshot'")).firstMatch
    }

    /// A slow drag from the middle of the front card, held at the end: the card follows the finger,
    /// the stamp comes up under it and reads, and the release commits. A flick would be gone in
    /// three frames. The card is found by where it is (the screen's middle, a little above centre)
    /// rather than by a query, which on a busy machine costs seconds per swipe.
    private func swipe(_ direction: Swipe) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(direction.vector),
                    withVelocity: .slow, thenHoldForDuration: 0.6)
    }

    /// The header's Trash button shares its label with the verdict button; the header is the higher one.
    private func topmost(_ query: XCUIElementQuery) -> XCUIElement {
        let all = query.allElementsBoundByIndex
        return all.min { $0.frame.minY < $1.frame.minY } ?? query.firstMatch
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 4) { back.tap() } else { app.buttons["Back"].tap() }
    }
}
