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

    @Test("Default icon variants are resolved by the injected scheme")
    func iconResolution() {
        #expect(AppAccentScheme.green.iconName(for: "defaultChestIcon") == "defaultChestIcon")
        #expect(AppAccentScheme.grey.iconName(for: "defaultChestIcon") == "grey_defaultChestIcon")
        #expect(AppAccentScheme.grey.iconName(for: "bicepsIcon") == "bicepsIcon")
    }

    @Test("Persisted accent contract remains compatible with existing installs")
    func persistedAccentCompatibility() {
        #expect(AppAccentScheme.storageKey == "defaultIconColorScheme")
        #expect(AppAccentScheme.green.rawValue == "green")
        #expect(AppAccentScheme.grey.rawValue == "grey")
    }
}
