import SwiftUI

/// The tile row's layout arithmetic, split out of the view.
///
/// Its own type because `TileScrollRow` is generic and cannot hold static stored
/// properties — but the real reason is testability: these are the numbers most
/// likely to regress when a reserved width or the visible-tile fraction changes,
/// and inside a `GeometryReader` they are only reachable by rendering.
/// Internal throughout: every consumer lives in this module now that no card
/// does its own arithmetic, and the tests reach it with `@testable import`.
enum TileScrollRowMetrics {
    /// Spacing between tiles and between the row's trailing columns.
    static let spacing: CGFloat = 8
    static let chevronWidth: CGFloat = 8

    /// The row overflows once it holds more tiles than it can show at once, so
    /// the threshold follows `visibleTileCount` rather than repeating its value.
    static func showsChevron(tileCount: Int, visibleTileCount: CGFloat) -> Bool {
        CGFloat(tileCount) > visibleTileCount
    }

    /// Width the tiles scroll within: the viewport minus the trailing columns.
    /// A column costs nothing while it is unoccupied.
    static func scrollAreaWidth(
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
    ///
    /// Deliberately independent of how many tiles there are. Capping it at the
    /// actual count removes the trailing gap, but then a lone tile grows to the
    /// full row width and the same exercise looks different from row to row —
    /// which reads worse than the gap.
    static func tileWidth(
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

/// What a tile row needs when the whole row is one control.
///
/// Bundled because the three are one decision: an action with no hint is
/// unannounced, and a hint with no action describes nothing.
public struct TileRowControl {
    let onTap: () -> Void
    let accessibilityHint: Text
    let accessibilityIdentifier: String?

    public init(
        onTap: @escaping () -> Void,
        accessibilityHint: Text,
        accessibilityIdentifier: String? = nil
    ) {
        self.onTap = onTap
        self.accessibilityHint = accessibilityHint
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

/// Horizontal scroller of equally wide tiles with an overflow chevron and an
/// optional trailing accessory.
///
/// `visibleTileCount` is fractional so the next tile peeks in. Once the row
/// holds more tiles than it can show, a compact chevron takes its own column
/// between the tiles and `trailingAccessory`, centred on the row.
///
/// The tile width is derived inside a `GeometryReader`, so the caller declares
/// the accessory's reserved width for the visible tile count to stay exact, and
/// gives the row an explicit height — a `GeometryReader` claims all the height
/// it is offered.
///
/// `control` is for a row that acts as one control: the action, the hint that
/// describes it and the identifier that names it are one decision, so they travel
/// together rather than as three optionals that could disagree. A row whose tiles
/// each do something different passes no control and attaches its own gestures
/// inside `tile`; nothing may be layered over the scroll view, because an
/// overlaid Button becomes the topmost hit-test target and swallows the
/// horizontal pan.
public struct TileScrollRow<Item: Identifiable, Tile: View, TrailingAccessory: View>: View {
    private let items: [Item]
    private let visibleTileCount: CGFloat
    private let reservedTrailingWidth: CGFloat
    private let chevronColor: Color
    private let control: TileRowControl?
    private let tile: (Item, Int, CGFloat) -> Tile
    private let trailingAccessory: TrailingAccessory

    public init(
        items: [Item],
        visibleTileCount: CGFloat,
        reservedTrailingWidth: CGFloat = 0,
        chevronColor: Color,
        control: TileRowControl? = nil,
        @ViewBuilder tile: @escaping (Item, Int, CGFloat) -> Tile,
        @ViewBuilder trailingAccessory: () -> TrailingAccessory = { EmptyView() }
    ) {
        self.items = items
        self.visibleTileCount = visibleTileCount
        self.reservedTrailingWidth = reservedTrailingWidth
        self.chevronColor = chevronColor
        self.control = control
        self.tile = tile
        self.trailingAccessory = trailingAccessory()
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing = TileScrollRowMetrics.spacing
            let showsChevron = TileScrollRowMetrics.showsChevron(
                tileCount: items.count,
                visibleTileCount: visibleTileCount
            )
            let scrollAreaWidth = TileScrollRowMetrics.scrollAreaWidth(
                available: geo.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                showsChevron: showsChevron
            )
            let tileWidth = TileScrollRowMetrics.tileWidth(
                available: geo.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                showsChevron: showsChevron,
                visibleTileCount: visibleTileCount
            )

            HStack(spacing: spacing) {
                scroller(width: scrollAreaWidth, tileWidth: tileWidth)

                if showsChevron {
                    // Its own column beside the accessory, not stacked above it:
                    // `maxHeight` centres it on the row.
                    Image(systemName: "chevron.compact.right")
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(chevronColor)
                        .frame(width: TileScrollRowMetrics.chevronWidth)
                        .frame(maxHeight: .infinity)
                }

                trailingAccessory
                    .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func scroller(width: CGFloat, tileWidth: CGFloat) -> some View {
        let strip = ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TileScrollRowMetrics.spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    tile(item, index, tileWidth)
                }
            }
        }
        .frame(width: width)

        if let control {
            strip
                .onTapGesture(perform: control.onTap)
                // `.combine` merges the tiles into one focusable element and the
                // action rides on that, which keeps the scroll view free of any
                // overlaid hit-test target.
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(control.accessibilityHint)
                .accessibilityAction { control.onTap() }
                // On the merged element rather than on the row, so it names the
                // thing it identifies instead of relying on the identifier
                // propagating into a subtree whose root was collapsed.
                .modifier(
                    OptionalAccessibilityIdentifier(identifier: control.accessibilityIdentifier)
                )
        } else {
            strip
        }
    }
}
