import SwiftUI

public enum AppStyle {
    public enum Padding {
        public static let horizontal: CGFloat = 18
        public static let screenHorizontal: CGFloat = 15
        public static let card: CGFloat = 16
        public static let titleTop: CGFloat = 8
        public static let titleBottom: CGFloat = 17
        public static let activeCardIconOverflow: CGFloat = 20
        public static let titleBottomBeforeActiveCard: CGFloat = titleBottom - activeCardIconOverflow
        public static let sectionSpacing: CGFloat = 18
        /// Gap above a sheet's bottom action bar (Cancel/Save row).
        public static let actionBarTop: CGFloat = 24
        public static let cardVertical: CGFloat = 8
    }

    public enum Layout {
        public static let cardHorizontalPadding: CGFloat = 16
        public static let cardHeaderSpacing: CGFloat = 10
        public static let chipHeight: CGFloat = 32
        public static let activeCardContentHeight: CGFloat = 80
        public static let activeCardMaxWidth: CGFloat = 400
        public static let categoryIconSize: CGFloat = 50
        public static let idleCategoryIconSize: CGFloat = 64
        public static let checkmarkSize: CGFloat = 36
        public static let playButtonSize: CGFloat = 36
        public static let playIconSize: CGFloat = 16
        public static let idlePlayButtonSize: CGFloat = 36
        public static let idlePlayIconSize: CGFloat = 14
        /// Optical centering offset for `play.fill` SF Symbol.
        /// The triangle's mass is left-leaning (apex on right), so a small
        /// positive x-offset visually centers it inside its circular container.
        public static let idlePlayIconOpticalOffset: CGFloat = 1.5
        /// Stroke width of the outer border around the idle exercise card.
        public static let idleCardBorderWidth: CGFloat = 1
        /// Stroke width of the metallic ring around the idle play button.
        /// Hairline (0.75) so the ring reads as a fine accent, not a heavy
        /// border. On @2x/@3x this resolves to a clean 1.5px / 2.25px line
        /// without aliasing.
        public static let idlePlayRingWidth: CGFloat = 0.75
        /// Blur radius of the soft mint outer glow rendered around the idle
        /// play button. Tuned together with `idlePlayButtonGlowSize` for a
        /// subtle hint that doesn't spill into the surrounding card surface.
        public static let idlePlayButtonGlowRadius: CGFloat = 6
        /// Diameter of the soft mint halo painted behind the idle play
        /// button. Only marginally larger than `idlePlayButtonSize` — the
        /// blur radius does the heavy lifting for the halo softness, so a
        /// near-equal disc keeps the component's reported bounds tight
        /// against the visible button (no excess padding around the glyph).
        public static let idlePlayButtonGlowSize: CGFloat = 38

        public static let completedBarWidth: CGFloat = 8
        public static let setRowBadgeSize: CGFloat = 26
        public static let analyticsImageSize: CGFloat = 60
        public static let seatIconSize: CGFloat = 30
        public static let analyticsEntryIconSize: CGFloat = 24
        /// Diameter of the lightbulb icon in the idle card's Tip column.
        /// Matches `analyticsEntryIconSize` so the Tip and Progress columns
        /// read as a visually symmetric pair.
        public static let tipIconSize: CGFloat = 30
        public static let tipBoxSize: CGFloat = 32
        public static let tipBoxCornerRadius: CGFloat = 8
        public static let separatorHeight: CGFloat = 32
        /// Stroke width of vertical column separators in metric rows.
        /// Hairline (0.5) so the separators read as fine guides rather than
        /// heavy dividers between values.
        public static let separatorWidth: CGFloat = 0.5
        public static let doneButtonWidth: CGFloat = 80
        public static let doneButtonHeight: CGFloat = 28
        public static let profileCardMinHeight: CGFloat = 100
        /// Unified minimum height for profile cards when collapsed so Nickname,
        /// Body Details, BMI and Tram header rows render at the same size.
        /// Sized for a two-line header (sectionHeadline + profileCardTitle)
        /// plus `Padding.card` on both sides.
        public static let profileCardCollapsedMinHeight: CGFloat = 72
        public static let profileAvatarSize: CGFloat = 80
        public static let profileInputPadding: CGFloat = 12
        public static let profileButtonPadding: CGFloat = 10
        public static let profileBMIBarHeight: CGFloat = 8
        public static let profileBMIThumbSize: CGFloat = 14
        public static let profileBottomSpacer: CGFloat = 100
        /// Friend-tile avatar diameter (Friends comparison section).
        public static let friendAvatarSize: CGFloat = 44
        /// Own-user-row avatar diameter in the Friends section (smaller than a
        /// friend tile to read as a header rather than a peer tile).
        public static let friendUserAvatarSize: CGFloat = 36
        /// Max width of a friend-tile name label before truncation.
        public static let friendTileNameMaxWidth: CGFloat = 60
        /// Height of the wheel-picker row used by the Body Details edit form.
        /// Matches the 150pt row used in `ExerciseWheelPickerRow` so the wheels
        /// feel consistent across the app.
        public static let profileWheelHeight: CGFloat = 150
        /// Reserved minimum height for the Tram departures area when expanded so
        /// swapping origin/destination doesn't collapse the card and yank the
        /// surrounding ScrollView. Sized for 3 departure rows + breathing room.
        public static let tramDeparturesAreaMinHeight: CGFloat = 180
        public static let numberPadKeySize: CGFloat = 60
        public static let numberPadSpacing: CGFloat = 12
        public static let scrollWheelItemHeight: CGFloat = 60
        public static let scrollWheelVisibleItems: Int = 5
        public static let scrollWheelSnapTolerance: CGFloat = 18
        /// Bottom padding for short sheet content to match wheel picker height.
        public static let sheetContentBottomPad: CGFloat = 23
        public static let workoutPickerWidth: CGFloat = 320
        public static let workoutPickerHeight: CGFloat = 220
        public static let workoutPickerWheelHeight: CGFloat = 150
        public static let overlayConfirmButtonSize: CGFloat = 32
        public static let grabberWidth: CGFloat = 36
        public static let grabberHeight: CGFloat = 5
        public static let capsuleToggleWidth: CGFloat = 44
        public static let capsuleToggleHeight: CGFloat = 26
        public static let capsuleToggleThumb: CGFloat = 22

        /// Leading radio button shown on selectable cards in deactivate/activate mode.
        public static let selectionRadioSize: CGFloat = 24
        public static let selectionRadioDot: CGFloat = 15
        public static let selectionRadioFrame: CGFloat = 26
        public static let selectionRadioStroke: CGFloat = 2
        public static let miniMenuMaxWidth: CGFloat = 320
    }

    public enum CornerRadius {
        public static let card: CGFloat = 16
        public static let bottomBarButton: CGFloat = 12
        public static let editPickerViewButton: CGFloat = 12
        public static let defaultButton: CGFloat = 12
        public static let sheet: CGFloat = 22
        public static let tile: CGFloat = 10
        public static let timerCard: CGFloat = 12
        public static let numberPadKey: CGFloat = 12
        public static let pill: CGFloat = 20
        public static let overlay: CGFloat = 20
        public static let capsuleToggle: CGFloat = 12
    }

    public enum Font {
        public static let navigationHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        public static let cardHeadline = SwiftUI.Font.system(size: 18, weight: .bold)
        /// Idle/Inactive exercise-card title (e.g. "Loop"). Smaller +
        /// less bold than `cardHeadline` so it reads as a refined label
        /// rather than a heavy header — matches the design-mockup look.
        public static let idleCardTitle = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let regularChip = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        public static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        public static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)

        public static let analyticsExerciseTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let analyticsExerciseData = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let analyticsHeadline = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let analyticsBigNumber = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let analyticsAxis = SwiftUI.Font.system(size: 9, weight: .medium)

        public static let categorySelectionNameFont = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let categoryTileTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let categoryTileCount = SwiftUI.Font.system(size: 16, weight: .black)
        public static let categoryTileBadge = SwiftUI.Font.system(size: 14, weight: .heavy)
        public static let categoryTileProgress = SwiftUI.Font.system(size: 12, weight: .heavy)

        public static let tileLabel = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let tileValue = SwiftUI.Font.system(size: 16, weight: .medium)
        public static let sectionTitle = SwiftUI.Font.system(size: 18, weight: .medium)
        public static let sectionHeadline = SwiftUI.Font.system(size: 18, weight: .semibold)
        public static let numberPadKey = SwiftUI.Font.system(size: 24, weight: .medium)
        public static let numberPadDisplay = SwiftUI.Font.system(size: 32, weight: .regular)
        public static let numberPadSymbol = SwiftUI.Font.system(size: 24, weight: .regular)
        public static let chartLabel = SwiftUI.Font.system(size: 10, weight: .regular)
        public static let chartAxisSmall = SwiftUI.Font.system(size: 10, weight: .medium)
        public static let pickerAction = SwiftUI.Font.system(size: 14, weight: .regular)

        public static let cardBoldTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        public static let cardSmallBold = SwiftUI.Font.system(size: 12, weight: .bold)
        public static let cardSmallLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        public static let cardTinyLabel = SwiftUI.Font.system(size: 9, weight: .regular)
        public static let cardValueBold = SwiftUI.Font.system(size: 16, weight: .bold)
        public static let cardSmallMedium = SwiftUI.Font.system(size: 11, weight: .bold)
        public static let metricLabel = SwiftUI.Font.system(size: 11, weight: .medium)

        public static let iconSymbol = SwiftUI.Font.system(size: 20, weight: .semibold)

        public static let calendarHeader = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let calendarSubheader = SwiftUI.Font.system(size: 12, weight: .medium)
        public static let calendarDay = SwiftUI.Font.system(size: 14, weight: .regular)
        public static let calendarDayBold = SwiftUI.Font.system(size: 14, weight: .bold)
        public static let dayChipLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        public static let dayChipNumber = SwiftUI.Font.system(size: 13, weight: .regular)
        public static let dayChipNumberBold = SwiftUI.Font.system(size: 13, weight: .bold)
        public static let detailCategory = SwiftUI.Font.system(size: 15, weight: .bold)
        public static let detailExercise = SwiftUI.Font.system(size: 14, weight: .medium)
        public static let detailBadge = SwiftUI.Font.system(size: 14, weight: .bold)
        public static let detailCaption = SwiftUI.Font.system(size: 12, weight: .medium)
        public static let streakLabel = SwiftUI.Font.system(size: 11, weight: .medium)
        public static let streakValue = SwiftUI.Font.system(size: 16, weight: .bold)

        public static let profileGreeting = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let profileSubtitle = SwiftUI.Font.system(size: 15, weight: .medium)
        public static let profileCardTitle = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let profileCardValue = SwiftUI.Font.system(size: 28, weight: .bold)
        public static let profileCardUnit = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let profileBMICategory = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let profileInputLabel = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let profileAvatarIcon = SwiftUI.Font.system(size: 36, weight: .medium)
        public static let profileEditIcon = SwiftUI.Font.system(size: 24, weight: .regular)
        public static let profileSmallIcon = SwiftUI.Font.system(size: 12, weight: .semibold)

        public static let sheetTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let sheetSectionLabel = SwiftUI.Font.system(size: 17, weight: .semibold)
        public static let sheetCaption = SwiftUI.Font.system(size: 12, weight: .regular)
        /// Small bold glyph inside a circular control (e.g. the "+" on the
        /// add-seat button).
        public static let sheetControlGlyph = SwiftUI.Font.system(size: 13, weight: .bold)
        public static let numberPadSelectedValue = SwiftUI.Font.system(size: 48, weight: .bold)
    }

    public enum Color {
        /// Accent ("green") family for the active `DefaultIconColorScheme`.
        /// Green scheme = original hexes (unchanged); grey scheme = warm orange.
        /// The green-family tokens below are computed from this so the whole app
        /// re-tints in grey mode without touching ~215 call sites.
        private static var palette: AccentPalette { DefaultIconColorScheme.current.palette }

        public static let backgroundColor = SwiftUI.Color(hex: "#0A090E")
        //Screen Background: #0A090E
        //Card Background:   #121417

        public static var primaryButton: SwiftUI.Color { green }
        //public static let exerciseCardBackground = SwiftUI.Color(hex: "#1B1D1F")
        public static let exerciseCardBackground = SwiftUI.Color(hex: "#232227")
        /// Base surface color for the Idle exercise card. Dedicated to the
        /// idle card so other cards/tiles app-wide stay on
        /// `exerciseCardBackground`.
        public static let idleCardBackground = SwiftUI.Color(hex: "#0E0F13")
        public static let idleCardSoft = SwiftUI.Color(hex: "#101116")
        public static let idleCardDark = SwiftUI.Color(hex: "#0C0D11")
        public static let idleCardBorder = SwiftUI.Color(hex: "#2F3033")
        public static let idleCardBorderLight = SwiftUI.Color.white.opacity(0.14)
        public static let idleCardBorderDark = SwiftUI.Color.white.opacity(0.10)
        public static let idleCardInnerGlow = SwiftUI.Color.white.opacity(0.0)

        public static let chipsBackground = grayDark

        public static let white = SwiftUI.Color.white
        public static let black = SwiftUI.Color.black
        public static let yellow = SwiftUI.Color.yellow

        public static let gray = SwiftUI.Color(hex: "#4D4E53")
        public static let grayDark = SwiftUI.Color(hex: "#383838")

        public static var greenBlack: SwiftUI.Color { palette.black }
        public static var greenDark: SwiftUI.Color { palette.dark }

        public static var green: SwiftUI.Color { palette.primary }
        public static var greenLight: SwiftUI.Color { palette.light }
        public static var greenMint: SwiftUI.Color { palette.mint }
        public static var greenFrost: SwiftUI.Color { palette.frost }
        public static var greenGlow: SwiftUI.Color { palette.glow }

        // MARK: Idle Card — Text Hierarchy
        /// Title text on the idle card (e.g. exercise name "Loop"). Slightly
        /// off-white so it reads soft against `idleCardBackground` instead of
        /// a hard pure-white edge.
        public static let idleTitle = SwiftUI.Color(hex: "#F2F2F2")
        /// Secondary metric labels on the idle card (e.g. "Weight", "Seat",
        /// "Data", expand/collapse chevron). Neutral grey so the eye
        /// anchors on the mint values, not the labels.
        public static let idleMetricLabel = SwiftUI.Color(hex: "#9A9A9A")
        /// Primary metric values + accent glyphs on the idle card (e.g. "20",
        /// "kg" weight unit suffix, seat arrows, progress icon, tip icon +
        /// label, play triangle). One shared mint token so all accent-tier
        /// **glyph/text/stroke** elements stay perfectly in sync.
        ///
        /// For large **solid filled shapes** (e.g. inactive-card checkmark
        /// disc, completion edge-indicator bar) use `idleAccentFill`
        /// instead — same hue, slightly darker, to compensate for the
        /// area-effect that makes solid blocks of the same hex read as
        /// more saturated than thin glyphs.
        public static var idleMetricValue: SwiftUI.Color { palette.idleMetricValue }
        /// Solid-fill variant of `idleMetricValue`, perceptually matched.
        /// Use for shapes that fill an area larger than a glyph or stroke
        /// (e.g. inactive-card checkmark disc, completion edge-indicator
        /// bar). Same mint family as `idleMetricValue`, ~7% darker per
        /// channel so the solid block doesn't visually outshine the
        /// glyph-tier accent elements.
        public static var idleAccentFill: SwiftUI.Color { palette.idleAccentFill }
        /// Vertical divider line between metric columns ("Weight" | "Seat" |
        /// "Data" | tip box) on the idle card. Dark neutral grey — sits
        /// quietly between the columns without competing with values or
        /// labels.
        public static let idleDivider = SwiftUI.Color(hex: "#3A3D3F")

        // MARK: Idle Card — Play Button Material
        /// Stroke color of the hairline border around the idle play button
        /// **and** the lightbulb tip box. Aligned with `idleMetricValue`
        /// so all teal accents (glyphs + outlines) read as one unified
        /// tone — matches the design-mockup's flat-accent look.
        public static var idlePlayRingBase: SwiftUI.Color { palette.idleMetricValue }
        /// Soft mint glow rendered around the outside of the play-button ring.
        /// Same family as `idleMetricValue` but heavily desaturated via low
        /// alpha so the halo reads as a hint, not as neon.
        public static var idlePlayRingGlow: SwiftUI.Color { palette.ringGlowBase.opacity(0.10) }

        public static let sheetBackground = SwiftUI.Color(hex: "#222025")
        public static let sheetInputBackground = SwiftUI.Color(hex: "#141518")
        public static let metricChipBackground = SwiftUI.Color(hex: "#100F15")
        public static var progressTrack: SwiftUI.Color { palette.progressTrack }
        /// Alternate progress-bar fill used when `DefaultIconColorScheme == .grey`
        /// (the default `.green` scheme keeps `greenGlow`). Solid fill only.
        public static let progressOrange = SwiftUI.Color(hex: "#F97316")
        /// Alternate progress-bar TRACK (empty portion) used when
        /// `DefaultIconColorScheme == .grey` (the `.green` scheme keeps the
        /// teal `progressTrack`).
        public static let progressTrackGrey = SwiftUI.Color(hex: "#2C2F36")
        public static let numberPadGray = SwiftUI.Color(hex: "#555555")
        public static var trainingAccent: SwiftUI.Color { palette.trainingAccent }
        public static let inProgressGold = SwiftUI.Color(hex: "#D4A843")

        /// Profile-family card fill. Matches the Analytics & Schedule cards
        /// (`Color.white.opacity(Opacity.subtleBackground)`) so every top-level
        /// tab page shares one neutral translucent grey, instead of the old
        /// bluish solid `#1A1920` that made Profile look different.
        public static let profileCardBackground = SwiftUI.Color.white.opacity(Opacity.subtleBackground)
        public static let bmiUnderweight = SwiftUI.Color(hex: "#5BA4CF")
        public static var bmiNormal: SwiftUI.Color { palette.glow }
        public static let bmiOverweight = SwiftUI.Color(hex: "#E8A838")
        public static let bmiObese = SwiftUI.Color(hex: "#E85A5A")

        public static let painAccent = SwiftUI.Color(hex: "#FF6B3D")

        /// Inline error text (form validation, load-failure messages).
        public static let error = SwiftUI.Color(hex: "#E85A5A")

        // MARK: Symptom-icon palette
        //
        // One token per `Symptom` case. Values are tuned for the dark sheet
        // (`AppStyle.Color.black` background, `chipsBackground` tile fill) and
        // hit the WCAG AA non-text contrast minimum (≥ 3:1) against both. The
        // app currently runs in `preferredColorScheme(.dark)` only — if a
        // light mode is added later these need to grow `.colorSet` Any/Dark
        // pairs.
        /// Pain — reuses the existing `painAccent` warm orange so the symptom
        /// chip and the bottom-bar feedback entry icon share one accent
        /// vocabulary.
        public static let symptomPain = painAccent
        /// Dizziness — bright cyan-blue, reads as "lightheaded".
        public static let symptomDizziness = SwiftUI.Color(hex: "#3FA9FF")
        /// Nausea — lime green, deliberately distinct from the
        /// forest-toned `green` used for energy/save accents.
        public static var symptomNausea: SwiftUI.Color { palette.nausea }
        /// Muscle weakness — dusty lavender, low-energy palette match.
        public static let symptomWeakness = SwiftUI.Color(hex: "#A89BC9")
    }

    public enum Opacity {
        public static let overlayBackdrop: Double = 0.55
        public static let subtleBackground: Double = 0.06
        public static let subtleStroke: Double = 0.15
        public static let grabberHandle: Double = 0.35
        public static let disabledElement: Double = 0.3
        public static let fadedOverlay: Double = 0.4
        public static let idleIconGlow: Double = 0.3
        public static let idlePlayButtonGlow: Double = 0.15
        public static let idleExpandedOverlay: Double = 0.6
        public static let separatorLine: Double = 0.3
        public static let secondaryLabel: Double = 0.6
        /// Placeholder text in styled sheet input fields (name, seat position).
        public static let placeholderText: Double = 0.35
        /// Hairline divider between rows in the "Additional options" list.
        public static let hairlineDivider: Double = 0.08
        /// Faded green outline for outlined controls (e.g. the seat-tile ✕ ring).
        public static let accentStroke: Double = 0.6
        /// Green glyph at slightly reduced strength (e.g. drag-handle dots).
        public static let accentGlyph: Double = 0.7
        /// Dashed green outline (e.g. the "add another seat setting" button).
        public static let accentDashedStroke: Double = 0.5
        public static let numberPadInactive: Double = 0.5
        public static let numberPadFade: Double = 0.2
        /// Milky selection tint (deactivate/activate multi-select) — matches the
        /// menu-bar / filter-toggle selected-pill look.
        public static let selectionTintFill: Double = 0.15
        public static let selectionTintStroke: Double = 0.35
        /// Hairline divider between Cancel and Deactivate/Activate in the morphed bar.
        public static let selectionDivider: Double = 0.2
    }

    public enum Shadow {
        public static let cardColor = SwiftUI.Color.black.opacity(0.42)
        public static let cardRadius: CGFloat = 8
        public static let cardY: CGFloat = 4
        public static let overlayRadius: CGFloat = 20
        public static let overlayY: CGFloat = 10
    }

    public enum DeviceLayout {
        public enum SizeClass {
            case compact
            case regular
            case large
            case extraLarge
        }

        public static var current: SizeClass {
            #if canImport(UIKit)
            let width = UIScreen.main.bounds.width
            if width >= 430 { return .extraLarge }
            if width > 400 { return .large }
            if width > 375 { return .regular }
            return .compact
            #else
            return .regular
            #endif
        }

        public static var cardSpacing: CGFloat {
            current == .compact ? 6 : 8
        }

        public static var cardPadding: CGFloat {
            switch current {
            case .extraLarge, .large: return 8
            case .regular: return 6
            case .compact: return 4
            }
        }

        public static var analyticsButtonWidth: CGFloat {
            switch current {
            case .extraLarge: return 80
            case .large: return 70
            case .regular: return 65
            case .compact: return 62
            }
        }

        public static var chipWidthVertical: CGFloat {
            current == .extraLarge ? 71 : 63
        }

        public static var iconContainerWidth: CGFloat {
            current == .extraLarge ? 82 : 72
        }

        public static var exerciseIconSize: CGFloat {
            current == .extraLarge ? 108 : 98
        }

        public static var analyticsToIconSpacing: CGFloat {
            switch current {
            case .extraLarge: return 12
            case .large: return 8
            case .regular: return 6
            case .compact: return 4
            }
        }

        public static var setRowWeightMinWidth: CGFloat {
            current == .compact ? 50 : 60
        }

        public static var setRowRepsMinWidth: CGFloat {
            current == .compact ? 110 : 120
        }

        public static var isExtraLarge: Bool {
            current == .extraLarge
        }

        public static var trainingSessionSpacing: CGFloat {
            switch current {
            case .compact: return 8
            case .regular: return 10
            case .large: return 12
            case .extraLarge: return 16
            }
        }

        public static var timerFontSize: CGFloat {
            switch current {
            case .compact: return 15
            case .regular: return 16
            case .large: return 18
            case .extraLarge: return 20
            }
        }
    }

    public enum Animation {
        public static let keyboardSpring = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.88)
        public static let snapSpring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    }

    public enum Duration {
        /// Long-press threshold to enter the deactivate selection from a card.
        public static let selectionLongPress: Double = 0.4
    }

    public enum Blur {
        public static let iconGlow: CGFloat = 12
    }

}
