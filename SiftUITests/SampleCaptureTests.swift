import XCTest

/// A development tool, not a test of Sift: captures real iOS screens from the simulator's built-in
/// apps to serve as the bundled sample screenshots (`Sift/Resources/SampleScreenshots/`). It launches
/// each app, answers any system permission alert (which `simctl` cannot dismiss), skips a "Continue"
/// splash, and attaches a full-screen capture. Skipped unless `SIFT_CAPTURE_SAMPLES=1` is in the
/// runner's environment:
///
///     xcodebuild … -only-testing:SiftUITests/SampleCaptureTests TEST_RUNNER_SIFT_CAPTURE_SAMPLES=1 test
@MainActor
final class SampleCaptureTests: XCTestCase {
    /// It answers the built-in apps' permission alerts, with an Allow button where there is one, so
    /// it runs on a simulator only: on a device it would change the permissions of someone's own apps
    /// (ADR-027, ADR-033).
    /// It writes nothing to Photos; its captures are test attachments. A device build still
    /// compiles it; the skip is at run time, before the first step.
    nonisolated override func setUpWithError() throws {
        try super.setUpWithError()
        #if !targetEnvironment(simulator)
        throw XCTSkip("simulator only: answers other apps' permission alerts")
        #endif
    }

    func testCaptureSamples() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIFT_CAPTURE_SAMPLES"] == "1",
                          "set SIFT_CAPTURE_SAMPLES=1 to capture sample screenshots")
        continueAfterFailure = true
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let apps = ["com.apple.Preferences", "com.apple.MobileAddressBook", "com.apple.Passbook", "com.apple.shortcuts",
                    "com.apple.mobilesafari", "com.apple.mobilecal", "com.apple.mobileslideshow", "com.apple.Maps"]
        for id in apps {
            let app = XCUIApplication(bundleIdentifier: id)
            app.launch()
            for _ in 0..<4 {
                sleep(2)
                let alert = springboard.alerts.firstMatch
                if alert.exists {
                    let allow = alert.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Allow'")).firstMatch
                    if allow.exists { allow.tap() } else { alert.buttons.firstMatch.tap() }
                }
                let splash = app.buttons["Continue"]
                if splash.exists { splash.tap() }
            }
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = id
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
