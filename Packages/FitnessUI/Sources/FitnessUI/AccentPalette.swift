import SwiftUI

/// Primitive accent ramp selected by ``AppAccentScheme`` and exposed to views
/// through ``AppColorTheme``.
///
/// - `green` reproduces the app's **original, byte-identical** hexes — selecting
///   the green scheme changes nothing, so existing snapshots stay pixel-stable.
/// - `grey` replaces the whole green family with a warm orange ramp; the dark
///   green-tinted structurals go **neutral-dark** (no green tint, no brown) so
///   the grey design has no leftover green accents.
///
/// Values are baked as explicit hex (reviewable, snapshot-stable) rather than a
/// runtime hue rotation. Dynamic colors intentionally do not live in
/// `AppStyle.Color`, because a static global lookup is invisible to SwiftUI's
/// dependency tracking.
public struct AccentPalette: Sendable {
    public let primary: Color           // green
    public let light: Color             // greenLight
    public let mint: Color              // greenMint
    public let frost: Color             // greenFrost
    public let glow: Color              // greenGlow (+ bmiNormal alias)
    public let black: Color             // greenBlack
    public let dark: Color              // greenDark
    public let trainingAccent: Color    // trainingAccent
    public let idleMetricValue: Color   // idleMetricValue (+ idlePlayRingBase)
    public let idleAccentFill: Color    // idleAccentFill
    public let ringGlowBase: Color      // idlePlayRingGlow base (opacity applied at use site)
    public let progressTrack: Color     // progressTrack
    public let nausea: Color            // symptomNausea

    /// Original green palette. The idle-card accent trio (`idleMetricValue`,
    /// `idleAccentFill`, `ringGlowBase`) was retuned from a pastel mint
    /// (#8CC7A8 / #7DB89A / #B7DCC5) toward a brightened version of the brand
    /// teal `primary` (#088177) so the idle card's accent reads as the same
    /// green used on the New-Workout selection chrome. All other hexes are the
    /// app's originals — do NOT change them (snapshots depend on them); the
    /// idle-card snapshot baselines were re-recorded for this retune.
    public static let green = AccentPalette(
        primary:         Color(hex: "#088177"),
        light:           Color(hex: "#7EBBAF"),
        mint:            Color(hex: "#80C2B4"),
        frost:           Color(hex: "#AACDC6"),
        glow:            Color(hex: "#3CC8A6"),
        black:           Color(hex: "#022123"),
        dark:            Color(hex: "#013334"),
        trainingAccent:  Color(hex: "#077484"),
        idleMetricValue: Color(hex: "#4FBEA6"),
        idleAccentFill:  Color(hex: "#45AE97"),
        ringGlowBase:    Color(hex: "#97DBCE"),
        progressTrack:   Color(hex: "#0A2726"),
        nausea:          Color(hex: "#9CCC30")
    )

    /// Grey design: warm orange ramp anchored on `progressOrange` (#F97316); dark
    /// structurals neutralised toward `progressTrackGrey` (#2C2F36). `glow` and
    /// `progressTrack` reuse the existing progress-bar tokens so the bar and the
    /// rest of the UI share one hex definition. Starting values — tune on device.
    public static let grey = AccentPalette(
        primary:         Color(hex: "#D15711"),
        light:           Color(hex: "#C9956F"),
        mint:            Color(hex: "#D19971"),
        frost:           Color(hex: "#CCB19D"),
        glow:            AppStyle.Color.progressOrange,    // #F97316
        black:           Color(hex: "#1F2023"),
        dark:            Color(hex: "#2E3034"),
        trainingAccent:  Color(hex: "#CC4E0E"),
        idleMetricValue: Color(hex: "#D6A27C"),
        idleAccentFill:  Color(hex: "#C7946F"),
        ringGlowBase:    Color(hex: "#DBBEA9"),
        progressTrack:   AppStyle.Color.progressTrackGrey, // #2C2F36
        nausea:          Color(hex: "#E0A52A")
    )
}
