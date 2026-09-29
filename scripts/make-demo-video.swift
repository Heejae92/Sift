// Turns a simulator recording of SiftUITests/DemoVideoTests into the demo video on the project page.
//
//     swift scripts/make-demo-video.swift raw.mov [--start S] [--end E] [--poster T]
//
// Writes, under docs/demo/:
//     sift-demo.mp4          H.264 (High), 480 px wide, 30 fps, no audio, moov atom first: plays in every browser
//     sift-demo-poster.png   one frame of the Review screen, sRGB, 480 px wide
//
// `raw.mov` is what `xcrun simctl io <UDID> recordVideo --codec=h264 --mask=black` wrote while the test
// ran. It starts on the home screen and ends on it, so the script trims both ends. The video starts at
// the first frame of the onboarding block, the orange Permission screen, and ends when the app does:
// Sift draws on flat colors, white canvases and full-bleed blocks, where a home screen is a wallpaper,
// and the black between the app closing and the home screen is one color. --start and --end (seconds
// into raw.mov) replace that guess. --poster (seconds into raw.mov) replaces the Review frame the script
// would pick: the first with the three verdict buttons showing, a second after they appear.
//
// The recorder writes a frame only when the screen changes, so a still screen is a gap in raw.mov. The
// output is resampled to a steady 30 fps, each frame the latest one at or before its time, so the pauses
// keep their length. The recorder tags its frames Display P3 but they hold sRGB numbers (tomato is
// 235, 89, 39 in the recording, in the design tokens and in `simctl io screenshot`), so the script reads
// them as sRGB and tags the output that way: treating them as P3 would push every color toward the edge
// of the gamut, and the video would not match the screenshots beside it.
//
// AVFoundation and VideoToolbox from the SDK, run by the `swift` that Xcode provides: no third-party code, no ffmpeg.

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

// MARK: - Settings

let outputWidth = 480
let framesPerSecond = 30
/// A minute of mostly still screens: this stays well under 8 MB.
let averageBitRate = 800_000
/// Trimming and the poster look at the recording through thumbnails this wide.
let thumbnailWidth = 64

// MARK: - Arguments

var inputURL: URL?
var start: Double?
var end: Double?
var posterTime: Double?
var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--start": start = arguments.next().flatMap(Double.init)
    case "--end": end = arguments.next().flatMap(Double.init)
    case "--poster": posterTime = arguments.next().flatMap(Double.init)
    default: inputURL = URL(fileURLWithPath: argument)
    }
}
guard let inputURL else {
    print("usage: swift scripts/make-demo-video.swift raw.mov [--start S] [--end E] [--poster T]")
    exit(2)
}
let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = repositoryRoot.appendingPathComponent("docs/demo", isDirectory: true)
let videoURL = outputDirectory.appendingPathComponent("sift-demo.mp4")
let posterURL = outputDirectory.appendingPathComponent("sift-demo-poster.png")

// MARK: - Reading the recording

let asset = AVURLAsset(url: inputURL)
let duration = try await asset.load(.duration).seconds
guard let track = try await asset.loadTracks(withMediaType: .video).first else {
    print("\(inputURL.path) has no video track")
    exit(1)
}
let naturalSize = try await track.load(.naturalSize)
/// Even, as H.264 wants; the poster uses the same size.
let outputHeight = Int((naturalSize.height * CGFloat(outputWidth) / naturalSize.width / 2).rounded()) * 2
print(String(format: "recording: %.0f x %.0f, %.1f s", naturalSize.width, naturalSize.height, duration))

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// The frames of the recording, decoded to BGRA in presentation order, each with its time. The recording
/// has a few placeholder samples with no time and no picture; they are skipped.
func frames(width: Int? = nil, height: Int? = nil) throws -> AnySequence<(time: Double, buffer: CVPixelBuffer)> {
    var settings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    if let width, let height {
        settings[kCVPixelBufferWidthKey as String] = width
        settings[kCVPixelBufferHeightKey as String] = height
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    reader.add(output)
    guard reader.startReading() else { fatalError("could not read \(inputURL.path): \(String(describing: reader.error))") }
    return AnySequence(AnyIterator {
        _ = reader  // the output stops working once its reader is gone
        while let sample = output.copyNextSampleBuffer() {
            let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            if time.isFinite, let buffer = CMSampleBufferGetImageBuffer(sample) { return (time, buffer) }
        }
        return nil
    })
}

/// The frame as an image whose color space is sRGB, whatever the recorder tagged it with: the numbers are
/// kept, not converted.
func image(of buffer: CVPixelBuffer) -> CGImage? {
    var image: CGImage?
    VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
    return image?.copy(colorSpace: sRGB)
}

/// `image` drawn into a `width` x `height` sRGB BGRA bitmap.
func draw(_ image: CGImage, width: Int, height: Int, into data: UnsafeMutableRawPointer?, bytesPerRow: Int) -> CGContext {
    let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

/// One frame of the recording, reduced to a thumbnail to look at.
struct Thumbnail {
    let time: Double
    let width: Int
    let height: Int
    /// BGRA.
    let bytes: [UInt8]

    /// The share of the picture below the status bar that its `count` most common colors cover, colors
    /// quantized to 5 bits a channel.
    func share(ofMostCommon count: Int) -> Double {
        var histogram: [Int: Int] = [:]
        var total = 0
        for index in stride(from: height / 16 * width * 4, to: bytes.count, by: 4) {
            histogram[Int(bytes[index] >> 3) | Int(bytes[index + 1] >> 3) << 5 | Int(bytes[index + 2] >> 3) << 10, default: 0] += 1
            total += 1
        }
        return Double(histogram.values.sorted(by: >).prefix(count).reduce(0, +)) / Double(max(total, 1))
    }

    /// One color: the white launch screen, the black between the app and the home screen (a spinner on
    /// it does not change that). So is the home screen fading in from that black: Sift never draws
    /// anything that dark.
    var isBlank: Bool { share(ofMostCommon: 1) >= 0.985 || brightness < 0.15 }

    /// The mean of the red, green and blue below the status bar, 0 to 1.
    var brightness: Double {
        var sum = 0, total = 0
        for index in stride(from: height / 16 * width * 4, to: bytes.count, by: 4) {
            sum += Int(bytes[index]) + Int(bytes[index + 1]) + Int(bytes[index + 2])
            total += 3
        }
        return Double(sum) / Double(max(total, 1) * 255)
    }

    /// Flat areas of color, as Sift draws; a wallpaper has none, and neither has the home screen dimmed
    /// as the app goes.
    var isFlat: Bool { share(ofMostCommon: 3) >= 0.50 }

    /// The onboarding block, `DSBlock.onboarding`: tomato, `trash.main`, sRGB (235, 89, 39), covers half
    /// of the Permission screen, less behind the system dialog.
    var showsOnboarding: Bool {
        var orange = 0, total = 0
        for index in stride(from: height / 16 * width * 4, to: bytes.count, by: 4) {
            if abs(Int(bytes[index + 2]) - 235) < 24, abs(Int(bytes[index + 1]) - 89) < 24, abs(Int(bytes[index]) - 39) < 24 { orange += 1 }
            total += 1
        }
        return Double(orange) / Double(max(total, 1)) >= 0.33
    }

    /// Whether Review's dock is showing: the tomato, yellow and cobalt verdict circles sit in the band
    /// between 80 % and 95 % of the height, and no other screen has all three there.
    var showsVerdictButtons: Bool {
        var tomato = 0, yellow = 0, cobalt = 0
        for row in Int(Double(height) * 0.80)..<Int(Double(height) * 0.95) {
            for column in 0..<width {
                let index = (row * width + column) * 4
                let b = Int(bytes[index]), g = Int(bytes[index + 1]), r = Int(bytes[index + 2])
                if r > 200, g > 60, g < 130, b < 90 { tomato += 1 }
                if r > 215, g > 175, b < 110 { yellow += 1 }
                if r < 90, g < 100, b > 170 { cobalt += 1 }
            }
        }
        let floor = width * height / 500
        return tomato > floor && yellow > floor && cobalt > floor
    }
}

func thumbnails() throws -> [Thumbnail] {
    let height = thumbnailWidth * Int(naturalSize.height) / Int(naturalSize.width)
    var found: [Thumbnail] = []
    for (time, buffer) in try frames(width: thumbnailWidth, height: height) {
        guard let image = image(of: buffer) else { continue }
        var bytes = [UInt8](repeating: 0, count: thumbnailWidth * height * 4)
        bytes.withUnsafeMutableBytes {
            _ = draw(image, width: thumbnailWidth, height: height, into: $0.baseAddress, bytesPerRow: thumbnailWidth * 4)
        }
        found.append(Thumbnail(time: time, width: thumbnailWidth, height: height, bytes: bytes))
    }
    return found.sorted { $0.time < $1.time }
}

// MARK: - Finding the app

let timeline = try thumbnails()
guard !timeline.isEmpty else {
    print("could not read any frame")
    exit(1)
}

/// From the first frame of the onboarding block (failing that, the first flat frame that is not one color)
/// to the first frame after the last flat one: the black between the app and the home screen, or the home
/// screen itself. A recording that stops with the app still up ends where it ends.
func appStretch() -> (start: Double, end: Double)? {
    func isApp(_ frame: Thumbnail) -> Bool { frame.isFlat && !frame.isBlank }
    guard let first = timeline.first(where: \.showsOnboarding) ?? timeline.first(where: isApp),
          let last = timeline.last(where: { $0.time >= first.time && isApp($0) }) else { return nil }
    return (first.time, timeline.first { $0.time > last.time }?.time ?? duration)
}

let stretch = appStretch()
guard let trimStart = start ?? stretch?.start, let trimEnd = end ?? stretch?.end, trimEnd > trimStart else {
    print("no stretch of the recording shows the app; pass --start and --end")
    exit(1)
}
print(String(format: "keeping %.2f s to %.2f s (%.1f s)", trimStart, trimEnd, trimEnd - trimStart))

// MARK: - The video

/// A `outputWidth` x `outputHeight` BGRA buffer holding `source`, tagged sRGB.
func scaled(_ source: CVPixelBuffer) -> CVPixelBuffer {
    var target: CVPixelBuffer?
    CVPixelBufferCreate(nil, outputWidth, outputHeight, kCVPixelFormatType_32BGRA, nil, &target)
    guard let image = image(of: source), let target else { fatalError("could not scale a frame") }
    CVPixelBufferLockBaseAddress(target, [])
    _ = draw(image, width: outputWidth, height: outputHeight, into: CVPixelBufferGetBaseAddress(target),
             bytesPerRow: CVPixelBufferGetBytesPerRow(target))
    CVPixelBufferUnlockBaseAddress(target, [])
    CVBufferSetAttachment(target, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
    CVBufferSetAttachment(target, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_sRGB, .shouldPropagate)
    CVBufferSetAttachment(target, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
    return target
}

/// Trim to `trimStart...trimEnd`, scale to `outputWidth`, and encode at a steady rate.
func exportVideo() async throws {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: videoURL)
    let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true  // moov atom first, so the page can start playing at once
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: outputWidth,
        AVVideoHeightKey: outputHeight,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: averageBitRate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: framesPerSecond * 2,
            AVVideoExpectedSourceFrameRateKey: framesPerSecond,
        ],
    ])
    writerInput.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
    writer.add(writerInput)
    guard writer.startWriting() else { fatalError("could not start: \(String(describing: writer.error))") }
    writer.startSession(atSourceTime: .zero)

    var upcoming = try frames().makeIterator()
    var next = upcoming.next()
    var current: CVPixelBuffer?
    let frameCount = Int(((trimEnd - trimStart) * Double(framesPerSecond)).rounded(.down))
    for tick in 0..<frameCount {
        let time = trimStart + Double(tick) / Double(framesPerSecond)
        var latest: CVPixelBuffer?
        while let frame = next, frame.time <= time {
            latest = frame.buffer
            next = upcoming.next()
        }
        if let latest { current = scaled(latest) }
        guard let current else { continue }  // the recording has no picture yet
        while !writerInput.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
        adaptor.append(current, withPresentationTime: CMTime(value: CMTimeValue(tick), timescale: CMTimeScale(framesPerSecond)))
    }
    writerInput.markAsFinished()
    await writer.finishWriting()
    if let error = writer.error { fatalError("encoding failed: \(error)") }
}

// MARK: - The poster

/// The first Review frame with its dock showing, a second later: the first card has decoded by then and
/// nothing is moving.
func choosePosterTime() -> Double? {
    timeline.first { $0.time >= trimStart && $0.time < trimEnd && $0.showsVerdictButtons }.map { $0.time + 1 }
}

/// The picture on screen at `time`: the latest frame at or before it, scaled like the video.
func exportPoster(at time: Double) throws {
    var shown: CVPixelBuffer?
    for frame in try frames() {
        if frame.time > time { break }
        shown = frame.buffer
    }
    guard let shown, let picture = image(of: shown) else { fatalError("no frame at or before \(time) s") }
    guard let converted = draw(picture, width: outputWidth, height: outputHeight, into: nil, bytesPerRow: 0).makeImage(),
          let destination = CGImageDestinationCreateWithURL(posterURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("could not write \(posterURL.path)")
    }
    CGImageDestinationAddImage(destination, converted, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(posterURL.path)") }
}

try await exportVideo()
let bytes = (try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int) ?? 0
print(String(format: "wrote %@ (%dx%d, %.1f s, %.1f MB)", videoURL.path, outputWidth, outputHeight, trimEnd - trimStart, Double(bytes) / 1_000_000))

guard let posterAt = posterTime ?? choosePosterTime() else {
    print("no Review frame found for the poster; pass --poster")
    exit(1)
}
try exportPoster(at: posterAt)
print(String(format: "wrote %@ (frame at %.2f s)", posterURL.path, posterAt))
