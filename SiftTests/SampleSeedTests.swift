// Simulator builds only, the same compile-time gate as the launch arguments of ADR-027 and ADR-032:
// a test build for a device does not contain this tool, so it can never write into a real library.
#if targetEnvironment(simulator)
import Foundation
import Photos
import Testing

/// A development tool, not a test of the app (ADR-033): adds the six bundled sample screenshots to
/// the simulator's Photos library a second time, dated in August 2026, 35 to 58 days before
/// 2026-09-28. They are due under the 30-day rule (ADR-032) and stay due, so Review shows real
/// screenshots as cards, while the copies seeded with `simctl addmedia`, dated the day they were
/// captured, keep the all-done block's "Next screenshot" line. The dates are fixed: a second run
/// finds each one already in the library and adds nothing.
///
/// Disabled unless `SIFT_SEED_SAMPLES=1` is in the test process's environment, so a normal test run
/// reports it as skipped. `xcodebuild` passes it on from its own environment, prefixed:
///
///     TEST_RUNNER_SIFT_SEED_SAMPLES=1 xcodebuild … -only-testing:SiftTests/SampleSeedTests test
///
/// The test runs inside the app, so it writes with the app's Photos access, which must be full. On a
/// fresh or erased simulator that access is still undetermined, so the order is: `simctl addmedia`,
/// then grant access (the tour's first run, or Get started → Allow Full Access), then this, then the
/// tour. After an erase, seed both again.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SIFT_SEED_SAMPLES"] == "1",
                "set SIFT_SEED_SAMPLES=1 (TEST_RUNNER_SIFT_SEED_SAMPLES=1 on xcodebuild) to seed the samples"))
struct SampleSeedTests {
    /// Newest first: 35, 39, 44, 48, 53 and 58 days before 2026-09-28, each in the daytime in
    /// California, where the simulator's clock is set.
    private static let seeds: [(name: String, taken: String)] = [
        ("sample-1", "2026-08-24T17:05:00Z"),
        ("sample-2", "2026-08-20T19:40:00Z"),
        ("sample-3", "2026-08-15T16:20:00Z"),
        ("sample-4", "2026-08-11T21:10:00Z"),
        ("sample-5", "2026-08-06T18:35:00Z"),
        ("sample-6", "2026-08-01T20:15:00Z"),
    ]

    @Test func seedBackdatedSamples() async throws {
        try #require(PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized,
                     "The app has no full Photos access on this simulator. Open it, tap Get started, choose Allow Full Access, then run this again.")
        for seed in Self.seeds {
            let taken = try Date(seed.taken, strategy: .iso8601)
            guard !Self.libraryHasImage(takenAt: taken) else { continue }
            let url = try #require(Bundle.main.url(forResource: seed.name, withExtension: "png"),
                                   "\(seed.name).png is not in the app bundle")
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
                request.creationDate = taken
            }
        }
        for seed in Self.seeds {
            let taken = try Date(seed.taken, strategy: .iso8601)
            #expect(Self.libraryHasImage(takenAt: taken), "\(seed.name) is not in the library at \(seed.taken)")
        }
    }

    /// Whether an image was taken within the second of `date`: the check that makes a rerun add nothing.
    private static func libraryHasImage(takenAt date: Date) -> Bool {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                        date as NSDate, date.addingTimeInterval(1) as NSDate)
        options.fetchLimit = 1
        return PHAsset.fetchAssets(with: .image, options: options).count > 0
    }
}
#endif
