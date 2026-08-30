import SwiftUI

public enum AppStyle {
    public enum Padding {
        public static let horizontal: CGFloat = 18
        public static let screenHorizontal: CGFloat = 15
        public static let card: CGFloat = 16
        public static let titleTop: CGFloat = 8
        /// Insets around the shared `SheetGrabber`, identical on every sheet so
        /// the handle sits at the same height in all of them.
        public static let sheetGrabberTop: CGFloat = 8
        public static let sheetGrabberBottom: CGFloat = 10
        public static let titleBottom: CGFloat = 17
        public static let activeCardIconOverflow: CGFloat = 20
        public static let sectionSpacing: CGFloat = 18
        /// Gap above a sheet's bottom action bar (Cancel/Save row).
        public static let actionBarTop: CGFloat = 24
        public static let cardVertical: CGFloat = 8
        /// Horizontal inset for the idle card's expanded coaching content.
        public static let idleExpandedContentHorizontal: CGFloat = 8
    }

    public enum Layout {
        public static let cardHorizontalPadding: CGFloat = 16
        public static let cardHeaderSpacing: CGFloat = 10
        /// Hairline outline width for the shared flat dark surface on iOS 27.
        public static let darkSurfaceOutlineWidth: CGFloat = 1
        public static let chipHeight: CGFloat = 32
        public static let activeCardContentHeight: CGFloat = 80
        public static let activeCardMaxWidth: CGFloat = 400
        public static let categoryIconSize: CGFloat = 50
        /// Body/muscle icon size on the exercise cards. The idle/active card
        /// reads as the focal item, so its icon is the larger of the two.
        public static let idleActiveCardIconSize: CGFloat = 78
        public static let checkmarkSize: CGFloat = 36
        public static let playButtonSize: CGFloat = 36
        public static let playIconSize: CGFloat = 16
        public static let idlePlayButtonSize: CGFloat = 40
        public static let idlePlayIconSize: CGFloat = 16
        /// Optical centering offset for `play.fill` SF Symbol.
        /// The triangle's mass is left-leaning (apex on right), so a small
        /// positive x-offset visually centers it inside its circular container.
        public static let idlePlayIconOpticalOffset: CGFloat = 2.0
        /// Stroke width of the outer border around the idle exercise card.
        public static let idleCardBorderWidth: CGFloat = 1
        public static let profileSurfaceBorderWidth: CGFloat = 1.5
        /// Hairline width of the neutral ring around the idle play button.
        public static let idlePlayRingWidth: CGFloat = 0.5
        /// Unscaled line heights of a set tile's value and reps rows.
        ///
        /// The rows are pinned to these rather than left to size themselves: a
        /// `Text` shrunk by `minimumScaleFactor` also reports a smaller height,
        /// which shortened the tile's centred stack and pulled the neighbouring
        /// lines inward. Adjacent tiles then disagreed about where the set label
        /// and the reps line sit — visible on any run mixing whole and decimal
        /// weights. Pinning the height confines scaling to the glyphs.
        public static let setTileValueRowHeight: CGFloat = 26
        public static let setTileRepsRowHeight: CGFloat = 16

        /// Ring around a set tile. Deliberately twice `idlePlayRingWidth`: the
        /// same hairline that gives a 40pt circle a crisp edge dissolves along a
        /// ~95pt rectangle, leaving the tile without a readable boundary.
        public static let setTileRingWidth: CGFloat = 1
        /// Blur radius of the soft mint outer glow rendered around the idle
        /// play button. Tuned together with `idlePlayButtonGlowSize` for a
        /// subtle hint that doesn't spill into the surrounding card surface.
        public static let idlePlayButtonGlowRadius: CGFloat = 3
        /// Diameter of the soft mint halo painted behind the idle play
        /// button. Only marginally larger than `idlePlayButtonSize` — the
        /// blur radius does the heavy lifting for the halo softness, so a
        /// near-equal disc keeps the component's reported bounds tight
        /// against the visible button (no excess padding around the glyph).
        public static let idlePlayButtonGlowSize: CGFloat = 42

        /// Legacy card-width contract retained for source compatibility.
        /// Frameless exercise rows now size from their container.
        @available(*, deprecated, message: "Frameless exercise rows size from their container.")
        public static let idleCardContentMinWidth: CGFloat = 400

        public static let completedBarWidth: CGFloat = 8
        public static let setRowBadgeSize: CGFloat = 26
        public static let setRowChipHorizontalPadding: CGFloat = 8
        public static let bilateralSideHeaderSize: CGFloat = 42
        public static let bilateralColumnSpacing: CGFloat = 4
        public static let bilateralMetricSpacingTight: CGFloat = 2
        public static let bilateralMetricSpacingCompact: CGFloat = 4
        public static let bilateralMetricSpacingComfortable: CGFloat = 8
        public static let bilateralPairSpacingTight: CGFloat = 4
        public static let bilateralPairSpacingCompact: CGFloat = 8
        public static let bilateralPairSpacingComfortable: CGFloat = 12
        public static let bilateralMetricChipHorizontalPaddingTight: CGFloat = 2
        public static let bilateralMetricChipHorizontalPadding: CGFloat = 4
        public static let activeSetRowSpacing: CGFloat = 16
        public static let activeSetVerticalPadding: CGFloat = 12
        /// Exactly three standard set rows remain visible before the set-only
        /// scroller is needed. The value includes the card's vertical insets.
        public static let trainingSheetStandardSetViewportHeight: CGFloat = 152
        /// Bilateral rows additionally reserve the existing L/R header while
        /// keeping three logical set pairs visible in the set-only scroller.
        public static let trainingSheetBilateralSetViewportHeight: CGFloat = 218
        public static let trainingSheetTimerHeight: CGFloat = 70
        public static let trainingSheetBilateralTimerHeight: CGFloat = 88
        public static let trainingSheetRailMaximumWidth: CGFloat = 120
        public static let trainingSheetRailMinimumWidth: CGFloat = 88
        public static let trainingSheetBilateralRailMinimumWidth: CGFloat = 72
        public static let trainingSheetBilateralContentHorizontalPadding: CGFloat = 4
        public static let trainingSheetContentHorizontalPadding: CGFloat = 20
        public static let trainingSheetContentMinimumHorizontalPadding: CGFloat = 8
        public static let trainingSheetSetVerticalOffset: CGFloat = 6
        public static let trainingSheetStandardSessionHeight: CGFloat = 212
        public static let trainingSheetBilateralSessionHeight: CGFloat = 270
        public static let trainingSheetHeaderSpacing: CGFloat = 16
        public static let trainingSheetActionBarTopSpacing: CGFloat = 14
        public static let trainingSheetBottomBarClearance: CGFloat = 76
        public static let trainingSheetMinimumBackdropHeight: CGFloat = 120
        public static let bilateralRepsChipContentMinWidth: CGFloat = 28
        public static let bilateralMetricMinimumScaleFactor: CGFloat = 0.65
        public static let analyticsInputActionWidth: CGFloat = 28
        public static let analyticsInputSideWidth: CGFloat = 32
        public static let analyticsInputSpacing: CGFloat = 8
        public static let analyticsInputMinimumScaleFactor: CGFloat = 0.75
        public static let bilateralAnalyticsMinimumScaleFactor: CGFloat = 0.7
        public static let bilateralAnalyticsRowHeight: CGFloat = 122
        public static let bilateralHeaderStrokeWidth: CGFloat = 2
        public static let analyticsImageSize: CGFloat = 60
        /// Width of the vertical seat-arrows glyph on the idle card.
        public static let seatIconSize: CGFloat = 8
        /// Height of the vertical seat-arrows glyph on the idle card.
        public static let seatIconHeight: CGFloat = 16
        /// Height of the Data chart glyph on the idle card.
        public static let idleMetricGlyphHeight: CGFloat = 26
        /// Shared interactive height for Weight/Reps, Seat, and Analytics.
        /// Matches the minimum tap target while centering their visual content.
        public static let idleMetricContentRowHeight: CGFloat = 44
        public static let idleMetricFooterRowHeight: CGFloat = 20
        /// Width of the Data chart glyph (landscape 2:1); height comes from `idleMetricGlyphHeight`.
        public static let analyticsEntryIconWidth: CGFloat = 52
        /// Vertical gap between the idle card's "Last run" trigger and its expanded set details.
        public static let idleLastRunExpandedTopSpacing: CGFloat = 12
        /// Fractional tile count fitted into a set-tile viewport so the next tile
        /// peeks in. Shared by the idle card's "Last run" row and the completed
        /// card's expanded row: the fraction is what sets the tile width, so the
        /// two rows only read as the same component while they share it.
        public static let setTileVisibleCount: CGFloat = 3.4
        /// Minimum interaction surface for tappable controls. Visual glyphs may
        /// remain smaller while their enclosing Button adopts this frame.
        public static let minimumTapTargetSize: CGFloat = 44
        /// Legacy metric-separator geometry retained for source compatibility.
        @available(*, deprecated, message: "Frameless exercise rows no longer render metric separators.")
        public static let separatorHeight: CGFloat = 32
        @available(*, deprecated, message: "Frameless exercise rows no longer render metric separators.")
        public static let idleMetricSeparatorHorizontalPadding: CGFloat = 8
        @available(*, deprecated, message: "Frameless inactive rows no longer render a trailing separator.")
        public static let inactiveTrailingSeparatorSpacing: CGFloat = 22
        /// Stroke width of vertical column separators in metric rows.
        /// Hairline (0.5) so the separators read as fine guides rather than
        /// heavy dividers between values.
        public static let separatorWidth: CGFloat = 0.5
        public static let profileCardMinHeight: CGFloat = 100
        /// Unified minimum height for profile cards when collapsed so Nickname,
        /// Body Details, BMI and Tram header rows render at the same size.
        /// Sized for a two-line header (sectionHeadline + profileCardTitle)
        /// plus `Padding.card` on both sides.
        public static let profileCardCollapsedMinHeight: CGFloat = 72
        public static let profileAvatarSize: CGFloat = 80
        public static let profileInputPadding: CGFloat = 12
        public static let profileButtonPadding: CGFloat = 10
        /// Prominent action geometry for workout-entry bottom sheets.
        public static let sheetActionSecondaryButtonWidth: CGFloat = 120
        public static let sheetActionPrimaryButtonMaxWidth: CGFloat = 225
        public static let sheetActionButtonHeight: CGFloat = 52
        /// Compact action geometry for Profile cards and Profile-owned flows.
        public static let profileActionSecondaryButtonWidth: CGFloat = 110
        public static let profileActionPrimaryButtonMaxWidth: CGFloat = 205
        /// Width of the compact two-option picker in the Profile card header.
        public static let profileColorPickerWidth: CGFloat = 136
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

        // MARK: Workout Tiles
        public static let workoutGridBottomPadding: CGFloat = 20
        public static let workoutTileCompactHeight: CGFloat = 120
        public static let workoutTileCompactSettingsIconSize: CGFloat = 30
        public static let workoutTileCompactCountOuterSize: CGFloat = 34
        public static let workoutTileCompactCountInnerSize: CGFloat = 26
        public static let workoutTileCompactCountOuterStroke: CGFloat = 3
        public static let workoutTileCompactCountInnerStroke: CGFloat = 1
        public static let workoutTileCompactCountInset: CGFloat = 20
        public static let workoutTileCompactSettingsTopInset: CGFloat = 22
        public static let workoutTileCompactBorderWidth: CGFloat = 2
        public static let workoutHeroSettingsIconSize: CGFloat = 24
        public static let workoutHeroBorderWidth: CGFloat = 1
        public static let workoutHeroMetricsTopSpacing: CGFloat = 30
        public static let workoutHeroArtworkWidth: CGFloat = 170
        public static let workoutHeroArtworkHeight: CGFloat = 121
        public static let workoutHeroArtworkTrailingOverflow: CGFloat = 38
        public static let workoutHeroStartChipHorizontalPadding: CGFloat = 12
        public static let workoutHeroStartChipVerticalPadding: CGFloat = 5
        public static let workoutHeroStartChipIconSpacing: CGFloat = 8
        public static let workoutHeroStartChipBorderWidth: CGFloat = 1
    }

    public enum CornerRadius {
        public static let card: CGFloat = 16
        public static let editPickerViewButton: CGFloat = 12
        public static let defaultButton: CGFloat = 12
        public static let sheet: CGFloat = 22
        public static let tile: CGFloat = 10
        public static let timerCard: CGFloat = 12
        public static let numberPadKey: CGFloat = 12
        public static let pill: CGFloat = 20
        public static let overlay: CGFloat = 20
        public static let capsuleToggle: CGFloat = 12
        public static let workoutHeroStartChip: CGFloat = 8
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
        public static let bilateralSideHeader = SwiftUI.Font.system(size: 22, weight: .medium)
        public static let trainingTimer = SwiftUI.Font.system(size: 16, weight: .bold)
        public static let trainingTimerLarge = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let trainingTimerCancel = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        public static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)
        /// Set index (1, 2, 3) at the left of a training-sheet set row.
        ///
        /// Sized to the reps value beside it so the row's two counted numbers
        /// form a pair. It previously used the generic 12pt `defaultFont`, which
        /// made the row's primary identifier smaller than its secondary "kg" and
        /// "of N" labels.
        public static let setRowNumber = SwiftUI.Font.system(size: 16, weight: .semibold)

        public static let analyticsExerciseTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let analyticsExerciseData = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let analyticsHeadline = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let analyticsBigNumber = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let analyticsAxis = SwiftUI.Font.system(size: 9, weight: .medium)
        public static let workoutEntryTitle = SwiftUI.Font.system(size: 36, weight: .bold)

        public static let categorySelectionNameFont = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let categoryTileTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let categoryTileCount = SwiftUI.Font.system(size: 16, weight: .black)
        public static let categoryTileBadge = SwiftUI.Font.system(size: 14, weight: .heavy)
        public static let categoryTileProgress = SwiftUI.Font.system(size: 12, weight: .heavy)
        public static let workoutHeroExerciseCount = SwiftUI.Font.system(size: 35, weight: .bold)
        public static let workoutHeroExerciseLabel = SwiftUI.Font.system(size: 12, weight: .medium)

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
        public static let cardValueBold = SwiftUI.Font.system(size: 16, weight: .bold)
        public static let cardSmallMedium = SwiftUI.Font.system(size: 11, weight: .bold)

        // Set tiles on the completed (inactive) card. Larger and left-aligned
        // compared to the compact idle tiles, so the weight is the first thing
        // read in the row; the unit and the reps footer stay quiet beside it.
        public static let setTileValue = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let setTileUnit = SwiftUI.Font.system(size: 12, weight: .regular)
        public static let setTileReps = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let setTileRepsUnit = SwiftUI.Font.system(size: 11, weight: .regular)
        public static let metricLabel = SwiftUI.Font.system(size: 11, weight: .medium)
        // Idle-card metric values — one token per metric so each can be tuned
        // independently. SF Pro bold default design, geometric tabular figures.
        /// Weight number, e.g. "80". Prominent because the metric is directly editable.
        public static let idleWeightValue = SwiftUI.Font.system(size: 20, weight: .bold)
        /// Unit suffix and secondary value line on the exercise cards: the "kg"
        /// beside a weight, the "reps" beside a rep gain, the "now …" footer, and
        /// the plain "Completed" label.
        ///
        /// One token for all of them because the design sets them at one size on
        /// both cards — the unit's ascender reaches only the belly of the adjacent
        /// digit, and everything secondary matches it. This replaces the earlier
        /// split into a 20pt idle-card unit and a 13pt completed-card unit, which
        /// made the same "kg" look different depending on the card it sat on.
        public static let cardMetricUnit = SwiftUI.Font.system(size: 13, weight: .regular)
        /// The "x" separator in the bodyweight "sets x reps" value (e.g. the "x"
        /// in "3x15"). Smaller than `idleWeightValue` so the numbers dominate and
        /// the glyph reads as a compact multiplier.
        public static let idleRepsSeparator = SwiftUI.Font.system(size: 14, weight: .bold)
        /// Seat position value, e.g. "4 / 7".
        public static let idleSeatValue = SwiftUI.Font.system(size: 19, weight: .bold)
        /// Center dot separating the two seat-position values.
        public static let idleSeatSeparator = SwiftUI.Font.system(size: 10, weight: .bold)
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
        public static let backgroundColor = SwiftUI.Color(hex: "#0A090E")
        //Screen Background: #0A090E
        //Card Background:   #121417

        // MARK: Ambient Screen Background
        /// Near-black base of `AmbientScreenBackground`. Slightly cooler and
        /// deeper than `backgroundColor` so the two tinted washes above it stay
        /// readable without being raised in opacity.
        public static let ambientBase = SwiftUI.Color(hex: "#07090B")
        /// Desaturated green wash, anchored bottom-leading. Green rather than
        /// petrol: at `#1E4A50` green and blue were level, which reads as cyan.
        /// Pulling blue down puts the tint on the green side the design asks for.
        /// Kept dull on purpose — at wash opacity a saturated green reads as a
        /// colour field instead of ambience.
        public static let ambientCool = SwiftUI.Color(hex: "#1C5C3C")
        /// Warm brown-orange wash, anchored trailing, upper-middle.
        ///
        /// Dark orange-red, hue ~16°. Do **not** rotate this further upward:
        /// 27° read as bronze and 40° as yellow-green next to `ambientCool` on
        /// the leading side. Both were tried and rejected. Proximity to the ~22°
        /// orange of the muscle artwork is harmless — that highlight is fully
        /// saturated at 60% brightness while this wash lands near luminance 24,
        /// so the two separate by brightness, not by hue.
        public static let ambientWarm = SwiftUI.Color(hex: "#6E2F18")

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
        /// Outline for the app's floating controls: the active-set timer card
        /// and the buttons that share its treatment, plus the home bottom menu
        /// bar, its back button, and its overflow button. One token so those
        /// outlines cannot drift apart — they are read side by side.
        public static let controlOutline = gray
        public static let grayDark = SwiftUI.Color(hex: "#383838")

        // MARK: Idle Card — Text Hierarchy
        /// Title text on the idle card (e.g. exercise name "Loop"). Slightly
        /// off-white so it reads soft against `idleCardBackground` instead of
        /// a hard pure-white edge.
        public static let idleTitle = SwiftUI.Color(hex: "#F2F2F2")
        /// Secondary metric labels on the idle card (e.g. "Weight", "Seat",
        /// "Data", expand/collapse chevron). Neutral grey so the eye
        /// anchors on the mint values, not the labels.
        public static let idleMetricLabel = SwiftUI.Color(hex: "#9A9A9A")
        /// Unit suffix beside the primary idle-card value, e.g. "kg", and the
        /// secondary footer labels on the idle/completed cards ("Last run",
        /// "Completed exercise") with their chevrons. Dimmer than
        /// `idleMetricLabel` so the mint value stays the only bright element in
        /// the row.
        public static let idleMetricUnit = SwiftUI.Color(hex: "#8A8B8C")
        // Accent-tier idle values and fills are dynamic and therefore live in
        // `AppColorTheme.accent`, not this fixed token set.
        /// Vertical divider line between metric columns and the trailing action
        /// on the idle card. Dark neutral grey — sits
        /// quietly between the columns without competing with values or
        /// labels.
        public static let idleDivider = SwiftUI.Color(hex: "#3A3D3F")

        public static let sheetBackground = SwiftUI.Color(hex: "#222025")
        public static let sheetInputBackground = SwiftUI.Color(hex: "#141518")
        public static let metricChipBackground = SwiftUI.Color(hex: "#100F15")
        /// The contour line that traces the muscle artwork's body, sampled from
        /// the rendered asset: hue 187° at 92% saturation and 46% brightness.
        ///
        /// Used to mark the active set in the training sheet — its number and the
        /// outline of its reps field — so the highlight belongs to the same
        /// family as the illustration rather than to the accent palette, whose
        /// `glow` sits at 165° and is far brighter.
        public static let muscleArtworkRim = SwiftUI.Color(hex: "#096A76")
        /// The same artwork hue raised to label brightness, for the active set's
        /// number. The rim value itself measures only 46% brightness — fine for
        /// the reps field's outline, where a whole connected shape carries the
        /// colour, but too dark for a single small digit.
        public static let muscleArtworkRimBright = SwiftUI.Color(hex: "#13AABD")
        /// Surface of the training sheet's primary "Done" action: dark petrol
        /// teal / deep cyan-green at hue 179°, deliberately not emerald or mint.
        ///
        /// The brightest stop of the gradient this surface used to run — flat by
        /// choice. No outline, glow or shadow belongs on it.
        public static let trainingDoneSurface = SwiftUI.Color(hex: "#0A8684")
        /// Grey-scheme progress fill. Kept as a fixed primitive for the palette.
        public static let progressOrange = SwiftUI.Color(hex: "#F97316")
        /// Grey-scheme progress track. Kept as a fixed primitive for the palette.
        public static let progressTrackGrey = SwiftUI.Color(hex: "#2C2F36")
        public static let numberPadGray = SwiftUI.Color(hex: "#555555")
        public static let inProgressGold = SwiftUI.Color(hex: "#D4A843")

        /// Compatibility alias for clients that require the flat base color.
        /// Profile feature views use the environment-injected
        /// `ProfileColorTheme` and `ProfileCardContainer` instead.
        public static let profileCardBackground = idleCardBackground
        public static let bmiUnderweight = SwiftUI.Color(hex: "#5BA4CF")
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
        // Nausea is palette-dependent and lives in `AppColorTheme.accent`.
        /// Muscle weakness — dusty lavender, low-energy palette match.
        public static let symptomWeakness = SwiftUI.Color(hex: "#A89BC9")
    }

    public enum Opacity {
        public static let overlayBackdrop: Double = 0.55
        public static let subtleBackground: Double = 0.06
        public static let subtleStroke: Double = 0.15
        /// Shared iOS-27 dark-surface base fill, replacing the raised native
        /// Glass bezel on app-owned cards and controls.
        public static let darkSurfaceFill: Double = 0.85
        /// Black depth layer over `darkSurfaceFill`; keeps the surface dark
        /// without introducing a directional highlight.
        public static let darkSurfaceDepth: Double = 0.2
        /// Single neutral outline around a dark surface.
        public static let darkSurfaceOutline: Double = 0.11
        public static let grabberHandle: Double = 0.35
        public static let disabledElement: Double = 0.3
        public static let fadedOverlay: Double = 0.4
        /// Peak strength of the cool wash in `AmbientScreenBackground`.
        public static let ambientCoolWash: Double = 0.16
        /// Peak strength of the warm wash in `AmbientScreenBackground`.
        public static let ambientWarmWash: Double = 0.26
        /// Corner darkening of the `AmbientScreenBackground` vignette.
        public static let ambientVignette: Double = 0.55
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
        public static let categoryTileIconGlow: Double = 0.5
        public static let categoryTileCompletionOverlay: Double = 0.3
        public static let workoutTileCompactDefaultFill: Double = 0.2
        public static let workoutHeroBorder: Double = 0.72
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
