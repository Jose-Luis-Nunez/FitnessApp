import SwiftUI
import Testing
@testable import FitnessUI

@Suite("App color theme")
struct AppColorThemeTests {
    @Test("Green and grey map to their complete primitive palettes")
    func paletteMapping() {
        let green = AppColorTheme(scheme: .green)
        let grey = AppColorTheme(scheme: .grey)

        #expect(green.scheme == .green)
        #expect(green.accent.primary == AccentPalette.green.primary)
        #expect(green.accent.glow == AccentPalette.green.glow)
        #expect(green.accent.progressTrack == AccentPalette.green.progressTrack)

        #expect(grey.scheme == .grey)
        #expect(grey.accent.primary == AccentPalette.grey.primary)
        #expect(grey.accent.glow == AccentPalette.grey.glow)
        #expect(grey.accent.progressTrack == AccentPalette.grey.progressTrack)
    }

    @Test("Profile roles derive from the selected app palette")
    func profilePaletteMapping() {
        #expect(AppColorTheme.green.profile.accent == AccentPalette.green.idleMetricValue)
        #expect(AppColorTheme.green.profile.accentFill == AccentPalette.green.idleAccentFill)
        #expect(AppColorTheme.grey.profile.accent == AccentPalette.grey.idleMetricValue)
        #expect(AppColorTheme.grey.profile.accentFill == AccentPalette.grey.idleAccentFill)
    }

    @Test("Default icon variants are resolved by the icon style, independent of the scheme")
    func iconResolution() {
        #expect(MuscleIconStyle.colored.iconName(for: "defaultChestIcon") == "defaultChestIcon")
        #expect(MuscleIconStyle.standard.iconName(for: "defaultChestIcon") == "grey_defaultChestIcon")
        #expect(MuscleIconStyle.standard.iconName(for: "bicepsIcon") == "bicepsIcon")
        #expect(AppColorTheme(scheme: .grey, muscleIcons: .colored).muscleIconName(for: "defaultAbsIcon") == "defaultAbsIcon")
        #expect(AppColorTheme(scheme: .green).muscleIconName(for: "defaultAbsIcon") == "grey_defaultAbsIcon")
        #expect(MuscleIconStyle.storageKey == "muscleIconStyle")
    }

    @Test("Progress track goes neutral with the standard figures, keeps the accent with the coloured ones")
    func progressTrackFollowsIconStyle() {
        #expect(AppColorTheme(scheme: .green, muscleIcons: .standard).progressTrack == AccentPalette.grey.progressTrack)
        #expect(AppColorTheme(scheme: .green, muscleIcons: .colored).progressTrack == AccentPalette.green.progressTrack)
        #expect(AppColorTheme(scheme: .grey, muscleIcons: .colored).progressTrack == AccentPalette.grey.progressTrack)
        #expect(AppColorTheme(scheme: .green, muscleIcons: .standard).artworkHalo == AppStyle.Color.artworkHaloNeutral)
        #expect(AppColorTheme(scheme: .green, muscleIcons: .colored).artworkHalo == AccentPalette.green.black)
    }

    @Test("Persisted accent contract remains compatible with existing installs")
    func persistedAccentCompatibility() {
        #expect(AppAccentScheme.storageKey == "defaultIconColorScheme")
        #expect(AppAccentScheme.green.rawValue == "green")
        #expect(AppAccentScheme.grey.rawValue == "grey")
    }
}
