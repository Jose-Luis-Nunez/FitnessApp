import SwiftUI
import FitnessCore

/// Horizontal scroller of `SetTileView`s showing a completed run's per-set
/// breakdown. Shared by the idle (`IdleActiveCardModelView`) and completed
/// (`InactiveCardModelView`) exercise cards.
///
/// Lays out three tiles across the available width; when more than three sets
/// exist a compact scroll chevron appears and the row scrolls horizontally.
/// Tapping the tiles invokes `onTap` (both cards open the analytics sheet).
///
/// An optional `trailingAccessory` (e.g. the reset button on the completed
/// card) is pinned to the trailing edge. Because the tile width is derived
/// inside a `GeometryReader`, the caller must declare the accessory's reserved
/// width via `reservedTrailingWidth` so the three tiles stay exact; the idle
/// card has no accessory and leaves it at the default `0`.
public struct SetTilesRow<TrailingAccessory: View>: View {
    private let setProgress: [SetProgress]
    private let hasWeight: Bool
    private let chevronColor: Color
    private let reservedTrailingWidth: CGFloat
    private let onTap: () -> Void
    private let trailingAccessory: TrailingAccessory

    public init(
        setProgress: [SetProgress],
        hasWeight: Bool,
        chevronColor: Color,
        reservedTrailingWidth: CGFloat = 0,
        onTap: @escaping () -> Void,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory = { EmptyView() }
    ) {
        self.setProgress = setProgress
        self.hasWeight = hasWeight
        self.chevronColor = chevronColor
        self.reservedTrailingWidth = reservedTrailingWidth
        self.onTap = onTap
        self.trailingAccessory = trailingAccessory()
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = setProgress.count > 3
            let scrollChevronWidth: CGFloat = 8
            let chevronArea: CGFloat = hasMoreThan3 ? scrollChevronWidth + spacing : 0
            let accessoryArea: CGFloat = reservedTrailingWidth > 0 ? reservedTrailingWidth + spacing : 0
            let scrollAreaWidth = geo.size.width - accessoryArea - chevronArea
            let tileWidth = (scrollAreaWidth - spacing * 2) / 3

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

                if hasMoreThan3 {
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
