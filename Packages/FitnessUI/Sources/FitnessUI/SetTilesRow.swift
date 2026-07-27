import SwiftUI
import FitnessCore

/// Horizontal scroller of `SetTileView`s showing a completed run's per-set
/// breakdown. Shared by the idle (`IdleActiveCardModelView`) and completed
/// (`InactiveCardModelView`) exercise cards.
///
/// Lays out three tiles across the available width by default; callers may
/// request a fractional visible-tile count to reveal a scrollable next tile.
/// When more than three sets exist, a compact scroll chevron appears unless
/// the caller uses the visible tile peek as its overflow affordance.
/// Tapping the tiles invokes `onTap` (both cards open the analytics sheet).
///
/// An optional `trailingAccessory` (e.g. the reset button on the completed
/// card) is pinned to the trailing edge. A second optional
/// `trailingRailAccessory` is stacked below the overflow chevron (or centered
/// when no chevron is needed). Because the tile width is derived
/// inside a `GeometryReader`, callers declare each accessory's reserved width
/// so the requested visible tile count stays exact.
public struct SetTilesRow<TrailingAccessory: View>: View {
    private let setProgress: [SetProgress]
    private let hasWeight: Bool
    private let chevronColor: Color
    private let reservedTrailingWidth: CGFloat
    private let reservedTrailingRailWidth: CGFloat
    private let visibleTileCount: CGFloat
    private let showsOverflowChevron: Bool
    private let onTap: () -> Void
    private let trailingAccessory: TrailingAccessory
    private let trailingRailAccessory: AnyView

    public init(
        setProgress: [SetProgress],
        hasWeight: Bool,
        chevronColor: Color,
        reservedTrailingWidth: CGFloat = 0,
        visibleTileCount: CGFloat = 3,
        showsOverflowChevron: Bool = true,
        onTap: @escaping () -> Void,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory = { EmptyView() }
    ) {
        self.setProgress = setProgress
        self.hasWeight = hasWeight
        self.chevronColor = chevronColor
        self.reservedTrailingWidth = reservedTrailingWidth
        self.reservedTrailingRailWidth = 0
        self.visibleTileCount = visibleTileCount
        self.showsOverflowChevron = showsOverflowChevron
        self.onTap = onTap
        self.trailingAccessory = trailingAccessory()
        self.trailingRailAccessory = AnyView(EmptyView())
    }

    public init<TrailingRailAccessory: View>(
        setProgress: [SetProgress],
        hasWeight: Bool,
        chevronColor: Color,
        reservedTrailingWidth: CGFloat = 0,
        reservedTrailingRailWidth: CGFloat,
        visibleTileCount: CGFloat = 3,
        showsOverflowChevron: Bool = true,
        onTap: @escaping () -> Void,
        @ViewBuilder trailingRailAccessory: () -> TrailingRailAccessory,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory = { EmptyView() }
    ) {
        self.setProgress = setProgress
        self.hasWeight = hasWeight
        self.chevronColor = chevronColor
        self.reservedTrailingWidth = reservedTrailingWidth
        self.reservedTrailingRailWidth = reservedTrailingRailWidth
        self.visibleTileCount = visibleTileCount
        self.showsOverflowChevron = showsOverflowChevron
        self.onTap = onTap
        self.trailingAccessory = trailingAccessory()
        self.trailingRailAccessory = AnyView(trailingRailAccessory())
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = setProgress.count > 3
            let showsChevron = hasMoreThan3 && showsOverflowChevron
            let scrollChevronWidth: CGFloat = 8
            let hasTrailingRailAccessory = reservedTrailingRailWidth > 0
            let showsTrailingRail = showsChevron || hasTrailingRailAccessory
            let trailingRailWidth = max(showsChevron ? scrollChevronWidth : 0, reservedTrailingRailWidth)
            let trailingRailArea: CGFloat = showsTrailingRail ? trailingRailWidth + spacing : 0
            let accessoryArea: CGFloat = reservedTrailingWidth > 0 ? reservedTrailingWidth + spacing : 0
            let scrollAreaWidth = geo.size.width - accessoryArea - trailingRailArea
            let resolvedVisibleTileCount = max(visibleTileCount, 1)
            let visibleSpacingCount = max(ceil(resolvedVisibleTileCount) - 1, 0)
            let visibleSpacing = spacing * visibleSpacingCount
            let tileWidth = (scrollAreaWidth - visibleSpacing) / resolvedVisibleTileCount

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

                if hasTrailingRailAccessory {
                    if showsChevron {
                        VStack(spacing: 0) {
                            Image(systemName: "chevron.compact.right")
                                .font(AppStyle.Font.regularChip)
                                .foregroundColor(chevronColor)
                                .frame(
                                    width: scrollChevronWidth,
                                    height: AppStyle.Layout.idleMetricContentRowHeight
                                )
                            Spacer(minLength: 0)
                            trailingRailAccessory
                        }
                        .frame(width: trailingRailWidth)
                        .frame(maxHeight: .infinity)
                    } else {
                        trailingRailAccessory
                            .frame(width: trailingRailWidth)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                } else if showsChevron {
                    Image(systemName: "chevron.compact.right")
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(chevronColor)
                        .frame(width: scrollChevronWidth)
                }

                trailingAccessory
            }
        }
    }
}
