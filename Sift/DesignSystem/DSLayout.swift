import CoreGraphics

// Layout tokens. Spacing, radius and grid follow the reference system verbatim; swipe physics
// are this app's own. `scripts/ds_tokens.py` parses `static let name: <CGFloat|Double|Int> = value`
// lines from this file and from DSMotion.swift, and exits 1 on any such declaration it cannot read.

/// Spacing scale 6 · 8 · 12 · 16 · 24 · 28 · 32.
enum DSSpace {
    /// Icon–text gap, inside chips
    static let s1: CGFloat = 6
    /// Small gaps, mobile gutter
    static let s2: CGFloat = 8
    /// Input / button inner padding
    static let s3: CGFloat = 12
    /// Default gap, mobile margin
    static let s4: CGFloat = 16
    /// Card padding, desktop gutter
    static let s5: CGFloat = 24
    /// Wide padding
    static let s6: CGFloat = 28
    /// Section separation
    static let s7: CGFloat = 32
}

/// Radius tracks the element's inner padding; nested radius = outer − gap.
enum DSRadius {
    /// Chips, badges, thumbnails
    static let xs: CGFloat = 6
    /// Secondary controls
    static let sm: CGFloat = 8
    /// Buttons, inputs, segmented control
    static let md: CGFloat = 12
    /// Cards
    static let lg: CGFloat = 16
    /// The screenshot card, sheets
    static let xl: CGFloat = 24
    /// Stamps, verdict buttons, toast, CTA pills
    static let pill: CGFloat = 999
}

/// Grid — single breakpoint. Desktop applies to the style guide, mobile to the app.
enum DSGrid {
    static let breakpoint: CGFloat = 1200
    static let desktopColumns: Int = 14
    static let desktopGutter: CGFloat = 24
    static let mobileColumns: Int = 4
    static let mobileMargin: CGFloat = 16
    static let mobileGutter: CGFloat = 8
}

/// Fixed sizes.
enum DSSize {
    /// Minimum hit target — pad the hit area, never the glyph.
    static let tapMin: CGFloat = 44
    static let verdictButton: CGFloat = 64
    /// The middle (up) button is smaller and raised so the row reads as a direction map.
    static let faveButton: CGFloat = 56
    static let faveButtonRaise: CGFloat = 8
    static let rewindButton: CGFloat = 44
    static let cardInset: CGFloat = 12
    static let thumbnailGutter: CGFloat = 4
    static let stackOffsetY: CGFloat = 14
    static let stackScaleStep: CGFloat = 0.06
    static let iconVerdict: CGFloat = 28
    static let iconChrome: CGFloat = 24
    static let iconInline: CGFloat = 20
    static let stampIcon: CGFloat = 24
    /// How far above the card's centre the FAVE stamp's centre sits, as a fraction of the card height.
    static let stampFaveRaise: CGFloat = 0.12
    /// AssetViewer: the scale a double-tap zooms to, and the ceiling a pinch can reach.
    static let viewerZoomDoubleTap: CGFloat = 2
    static let viewerZoomMax: CGFloat = 4
    /// A color block gives its face this share of its height, centred; the face fills that region
    /// as far as the width allows (owner, 2026-09-27: "아이콘은 화면의 반 이상 쓰도록").
    static let blockFaceShare: CGFloat = 0.5
    static let focusRing: CGFloat = 3
    static let gridColumns: Int = 3
    static let stackDepth: Int = 3
}

/// Swipe physics. Distances in pt, velocity in pt/s, angles in degrees.
/// Sectors (θ = atan2(-dy, dx), 0° = right): ARCHIVE (−45, 45] · FAVE (45, 135] ·
/// TRASH (135, 225] · DOWN dead zone (225, 315].
enum DSSwipe {
    /// Commit when travel ≥ this …
    static let commitDistance: CGFloat = 120
    /// … or when velocity along the sector axis ≥ this (with at least `minTravelForVelocity`).
    static let commitVelocity: CGFloat = 800
    static let minTravelForVelocity: CGFloat = 48
    /// Rotation = dx / rotationDivisor, clamped to ±maxRotationDegrees.
    static let rotationDivisor: CGFloat = 20
    static let maxRotationDegrees: CGFloat = 12
    /// Resting tilt of the TRASH (+) and ARCHIVE (−) stamps; FAVE sits at 0°. Equal to
    /// `maxRotationDegrees`, so a stamp on a fully tilted card reads as printed on it.
    static let stampTiltDegrees: CGFloat = 12
    /// Stamp opacity ramps 0→1 between these distances; the end equals `commitDistance`,
    /// so a fully opaque stamp IS the "release will commit" signal.
    static let stampRevealStart: CGFloat = 20
    static let stampRevealEnd: CGFloat = 120
    /// A sector change needs θ to cross this far into the neighbour (no flicker on a boundary).
    static let sectorHysteresisDegrees: CGFloat = 6
    /// Exit throw distance and final rotation.
    static let exitDistanceX: CGFloat = 720
    static let exitDistanceY: CGFloat = 840
    static let exitRotationDegrees: CGFloat = 18
    /// Down drag follows the finger at this fraction (rubber band) and never commits.
    static let downFollow: CGFloat = 0.35
    /// Up drag lifts the card to this scale at `commitDistance`.
    static let upScale: CGFloat = 1.03
    /// Fraction of the exit animation at which the side effect fires and the next card is promoted.
    static let promoteAt: CGFloat = 0.6
}

/// Opacity applied to a whole control, as opposed to a color's own alpha (those live in `DSColor`).
enum DSOpacity {
    /// Disabled buttons, and Rewind with nothing to rewind. Never the only signal: the control also
    /// carries the disabled trait (P-19).
    static let disabled: CGFloat = 0.45
}
