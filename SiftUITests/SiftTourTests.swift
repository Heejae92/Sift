import XCTest

/// A screenshot tour of the real app on a simulator: grants photo access through the system dialog
/// (the only way that works on this runtime — `simctl privacy grant photos` is ignored), then walks
/// Permission → Review (three swipes and a rewind) → Trash (viewer, purge sheet) → Library (both
/// segments) → Credits, attaching a screenshot at each stop. Seed the library in this order:
///
///     xcrun simctl addmedia booted Sift/Resources/SampleScreenshots/sample-*.png
///     xcodebuild … -only-testing:SiftUITests test                  # first run: grants access
///     TEST_RUNNER_SIFT_SEED_SAMPLES=1 xcodebuild … -only-testing:SiftTests/SampleSeedTests test
///     xcodebuild … -only-testing:SiftUITests test -resultBundlePath /tmp/sift-tour.xcresult
///     xcrun xcresulttool export attachments --path /tmp/sift-tour.xcresult --output-path /tmp/sift-tour
///
/// The seed tool writes with the app's Photos access, so access comes first: the tour's first run
/// grants it, or Get started → Allow Full Access in the app does. After an erase, seed both again.
/// The seed tool adds backdated copies of the samples (ADR-033), which are due and come up as cards.
/// The app is launched with `-SiftAllImages` (ADR-027) so the simulator's stock photos, years old,
/// come up too. The `addmedia` copies are under 30 days old and wait (ADR-032): while one of them is
/// unreviewed, the all-done frame names the day it comes due.
/// The tour asserts only that each screen appears; it is a smoke test with pictures, not a spec.
@MainActor  // XCUIApplication and its queries are main-actor isolated; XCTest runs the case on the main thread
final class SiftTourTests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var shot = 0

    func testTour() throws {
        continueAfterFailure = true
        app.launchArguments = ["-SiftAllImages"]
        app.launch()

        // Permission (only on a fresh install; a granted install goes straight to Review)
        let cta = app.buttons["Get started"]
        if cta.waitForExistence(timeout: 8) {
            snap("permission")
            cta.tap()
            let allow = springboard.buttons["Allow Full Access"]
            // After a fresh erase the photos backend can take a while to raise the dialog.
            if allow.waitForExistence(timeout: 30) { allow.tap() }
        }

        // Review
        let trashHeader = topmost(app.buttons.matching(identifier: "Trash"))
        XCTAssertTrue(trashHeader.waitForExistence(timeout: 30), "Review header did not appear")
        sleep(2)  // let the first cards decode
        snap("review")

        let card = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Screenshot'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "front card not found")
        card.swipeLeft()   // TRASH
        sleep(1)
        snap("review-after-trash")
        frontCard().swipeRight()  // ARCHIVE
        sleep(1)
        frontCard().swipeUp()     // FAVE
        sleep(1)
        snap("review-after-fave")
        let rewind = app.buttons["Rewind"]
        if rewind.waitForExistence(timeout: 4), rewind.isEnabled { rewind.tap(); sleep(1); snap("review-after-rewind") }

        // Sift the rest, so the all-done block is on the tour too
        for _ in 0..<20 {
            let next = frontCard()
            guard next.waitForExistence(timeout: 2) else { break }
            next.swipeLeft()
            usleep(600_000)
        }
        sleep(2)
        snap("all-done")

        // Trash
        topmost(app.buttons.matching(identifier: "Trash")).tap()
        let purgeAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete all'")).firstMatch
        XCTAssertTrue(purgeAll.waitForExistence(timeout: 8), "Trash screen did not appear")
        sleep(1)
        snap("trash")
        let cell = app.buttons.matching(NSPredicate(format: "label MATCHES '.*[0-9]{4}.*'")).firstMatch
        if cell.waitForExistence(timeout: 4) {
            cell.tap()
            let close = app.buttons["Close"]
            if close.waitForExistence(timeout: 6) { sleep(1); snap("viewer-trash"); close.tap() }
        }
        if purgeAll.waitForExistence(timeout: 4), purgeAll.isEnabled {
            purgeAll.tap()
            let keep = app.buttons["Keep"]
            if keep.waitForExistence(timeout: 6) { snap("purge-sheet"); keep.tap() }
        }
        goBack()

        // Library
        app.buttons["Library"].tap()
        let archiveSegment = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Archive'")).firstMatch
        XCTAssertTrue(archiveSegment.waitForExistence(timeout: 8), "Library did not appear")
        sleep(1)
        snap("library-favorites")
        archiveSegment.tap()
        sleep(1)
        snap("library-archive")
        let libraryCell = app.buttons.matching(NSPredicate(format: "label MATCHES '.*[0-9]{4}.*'")).firstMatch
        if libraryCell.waitForExistence(timeout: 4) {
            libraryCell.tap()
            let close = app.buttons["Close"]
            if close.waitForExistence(timeout: 6) { sleep(1); snap("viewer-library"); close.tap() }
        }
        let icons = app.buttons["Icons"]
        if icons.waitForExistence(timeout: 4) {
            icons.tap()
            sleep(1)
            snap("credits")
            goBack()
        }
        goBack()
        XCTAssertTrue(topmost(app.buttons.matching(identifier: "Trash")).waitForExistence(timeout: 8), "did not return to Review")
    }

    // MARK: - Helpers

    private func frontCard() -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Screenshot'")).firstMatch
    }

    /// The header's Trash button shares its label with the verdict button; the header is the higher one.
    private func topmost(_ query: XCUIElementQuery) -> XCUIElement {
        let all = query.allElementsBoundByIndex
        return all.min { $0.frame.minY < $1.frame.minY } ?? query.firstMatch
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 4) { back.tap() } else { app.buttons["Back"].tap() }
        sleep(1)
    }

    private func snap(_ name: String) {
        shot += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = String(format: "%02d-%@", shot, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
