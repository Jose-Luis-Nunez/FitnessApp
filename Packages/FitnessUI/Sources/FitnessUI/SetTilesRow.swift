import SwiftUI
import FitnessCore
import FitnessResources

/// A completed run's per-set breakdown, shared by the idle
/// (`IdleActiveCardModelView`) and completed (`InactiveCardModelView`) exercise
/// cards.
///
/// A thin arrangement of `SetTileView`s over `TileScrollRow`, which owns the
/// scrolling, the overflow chevron and the trailing accessory column. The row
/// acts as one control — tapping anywhere in it opens the analytics sheet — so
/// it hands `TileScrollRow` a row-level `onTap` rather than per-tile gestures.
public struct SetTilesRow<TrailingAccessory: View>: View {
    private let setProgress: [SetProgress]
    private let hasWeight: Bool
    private let chevronColor: Color
    private let reservedTrailingWidth: CGFloat
    private let visibleTileCount: CGFloat
    private let onTap: () -> Void
    private let tilesAccessibilityIdentifier: String?
    private let trailingAccessory: TrailingAccessory

    public init(
        setProgress: [SetProgress],
        hasWeight: Bool,
        chevronColor: Color,
        reservedTrailingWidth: CGFloat,
        visibleTileCount: CGFloat,
        onTap: @escaping () -> Void,
        tilesAccessibilityIdentifier: String? = nil,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory
    ) {
        self.setProgress = setProgress
        self.hasWeight = hasWeight
        self.chevronColor = chevronColor
        self.reservedTrailingWidth = reservedTrailingWidth
        self.visibleTileCount = visibleTileCount
        self.onTap = onTap
        self.tilesAccessibilityIdentifier = tilesAccessibilityIdentifier
        self.trailingAccessory = trailingAccessory()
    }

    public var body: some View {
        TileScrollRow(
            items: setProgress,
            visibleTileCount: visibleTileCount,
            reservedTrailingWidth: reservedTrailingWidth,
            chevronColor: chevronColor,
            control: TileRowControl(
                onTap: onTap,
                accessibilityHint: Text(AppText.accessibilityShowsExerciseAnalytics),
                accessibilityIdentifier: tilesAccessibilityIdentifier
            ),
            tile: { item, index, width in
                SetTileView(
                    setNumber: index + 1,
                    weight: item.weight,
                    reps: item.currentReps,
                    hasWeight: hasWeight
                )
                .frame(width: width)
            },
            trailingAccessory: { trailingAccessory }
        )
    }
}
