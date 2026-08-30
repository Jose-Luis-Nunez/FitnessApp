import SwiftUI
import FitnessCore
import FitnessResources

/// The set-tile row's layout arithmetic, split out of the view.
///
/// `SetTilesRow` is generic over its accessory, which cannot hold static stored
/// properties — but the real reason this is its own type is testability: these
/// are the numbers most likely to regress when a reserved width or the
/// visible-tile fraction changes, and inside a `GeometryReader` they are only
/// reachable by rendering.
public enum SetTilesRowMetrics {
    /// Spacing between tiles and between the row's trailing columns.
    public static let spacing: CGFloat = 8
    public static let chevronWidth: CGFloat = 8

    /// The row overflows once it holds more tiles than it can show at once, so
    /// the threshold follows `visibleTileCount` rather than repeating its value.
    public static func showsChevron(setCount: Int, visibleTileCount: CGFloat) -> Bool {
        CGFloat(setCount) > visibleTileCount
    }

    /// Width the tiles scroll within: the viewport minus the trailing columns.
    /// A column costs nothing while it is unoccupied.
    public static func scrollAreaWidth(
        available: CGFloat,
        reservedTrailingWidth: CGFloat,
        showsChevron: Bool
    ) -> CGFloat {
        let chevronArea: CGFloat = showsChevron ? chevronWidth + spacing : 0
        let accessoryArea: CGFloat = reservedTrailingWidth > 0 ? reservedTrailingWidth + spacing : 0
        return available - chevronArea - accessoryArea
    }

    /// Width of one tile. `visibleTileCount` is fractional so the next tile
    /// peeks in; the spacing subtracted is that of the whole tiles only.
    public static func tileWidth(
        available: CGFloat,
        reservedTrailingWidth: CGFloat,
        showsChevron: Bool,
        visibleTileCount: CGFloat
    ) -> CGFloat {
        let resolved = max(visibleTileCount, 1)
        let visibleSpacingCount = max(ceil(resolved) - 1, 0)
        let scrollArea = scrollAreaWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: showsChevron
        )
        return (scrollArea - spacing * visibleSpacingCount) / resolved
    }
}

/// Horizontal scroller of `SetTileView`s showing a completed run's per-set
/// breakdown. Shared by the idle (`IdleActiveCardModelView`) and completed
/// (`InactiveCardModelView`) exercise cards.
///
/// `visibleTileCount` is fractional so the next tile peeks in. Once the row
/// holds more sets than it can show at once, a compact scroll chevron takes its
/// own column between the tiles and `trailingAccessory`, centred on the tile
/// row.
///
/// Tapping the tiles invokes `onTap` (both cards open the analytics sheet).
/// Because the tile width is derived inside a `GeometryReader`, the caller
/// declares the accessory's reserved width so the requested visible tile count
/// stays exact; the arithmetic itself lives in `SetTilesRowMetrics`.
public struct SetTilesRow<TrailingAccessory: View>: View {
    private let setProgress: [SetProgress]
    private let hasWeight: Bool
    private let chevronColor: Color
    private let reservedTrailingWidth: CGFloat
    private let visibleTileCount: CGFloat
    private let onTap: () -> Void
    private let trailingAccessory: TrailingAccessory

    public init(
        setProgress: [SetProgress],
        hasWeight: Bool,
        chevronColor: Color,
        reservedTrailingWidth: CGFloat,
        visibleTileCount: CGFloat,
        onTap: @escaping () -> Void,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory
    ) {
        self.setProgress = setProgress
        self.hasWeight = hasWeight
        self.chevronColor = chevronColor
        self.reservedTrailingWidth = reservedTrailingWidth
        self.visibleTileCount = visibleTileCount
        self.onTap = onTap
        self.trailingAccessory = trailingAccessory()
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing = SetTilesRowMetrics.spacing
            let showsChevron = SetTilesRowMetrics.showsChevron(
                setCount: setProgress.count,
                visibleTileCount: visibleTileCount
            )
            let scrollAreaWidth = SetTilesRowMetrics.scrollAreaWidth(
                available: geo.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                showsChevron: showsChevron
            )
            let tileWidth = SetTilesRowMetrics.tileWidth(
                available: geo.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                showsChevron: showsChevron,
                visibleTileCount: visibleTileCount
            )

            HStack(spacing: spacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(setProgress.enumerated()), id: \.element.id) { index, item in
                            SetTileView(
                                setNumber: index + 1,
                                weight: item.weight,
                                reps: item.currentReps,
                                hasWeight: hasWeight
                            )
                            .frame(width: tileWidth)
                        }
                    }
                }
                .frame(width: scrollAreaWidth)
                .onTapGesture(perform: onTap)
                // A bare tap gesture is invisible to VoiceOver, so opening
                // analytics from the tiles used to be pointer-only. The fix has
                // to stay clear of hit testing: an overlaid transparent Button
                // — the pattern the idle card uses over its static chart glyph —
                // becomes the topmost hit-test target here and swallows the
                // horizontal pan, stranding every set past the visible ones
                // behind a chevron that still advertises them.
                //
                // `.combine` instead merges the tiles into one focusable element
                // carrying their values, and the action rides on that. Nothing
                // is layered over the scroll view, so the pan is untouched.
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text(AppText.accessibilityShowsExerciseAnalytics))
                .accessibilityAction { onTap() }

                if showsChevron {
                    // Its own column beside the accessory, not stacked above it:
                    // `maxHeight` centres it on the tile row.
                    Image(systemName: "chevron.compact.right")
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(chevronColor)
                        .frame(width: SetTilesRowMetrics.chevronWidth)
                        .frame(maxHeight: .infinity)
                }

                trailingAccessory
                    .frame(maxHeight: .infinity)
            }
        }
    }
}
