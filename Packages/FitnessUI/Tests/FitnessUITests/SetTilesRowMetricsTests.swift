import CoreGraphics
import FitnessTestSupport
import Testing
@testable import FitnessUI

/// The set-tile row's width arithmetic is shared by the idle and completed
/// exercise cards. These pin the numbers it produces; the rendering itself is
/// covered by the card snapshots.
@Suite("Set Tiles Row — Metrics", .tags(.fast))
struct SetTilesRowMetricsTests {

    /// The viewport both cards hand the row on the reference device, and the
    /// trailing column both reserve for their circular control.
    private let available: CGFloat = 361
    private let reservedTrailingWidth = ExerciseCardLayout.TrailingControl.columnWidth

    /// The configuration both cards pass, pinned to concrete numbers rather than
    /// re-derived from the production formula — restating the formula would
    /// still pass if the formula itself changed.
    ///
    /// 361 − (8 chevron + 8) − (44 column + 8) = 293 scrollable points;
    /// minus three inter-tile gaps = 269, over 3.4 tiles = 79.12.
    @Test
    func theSharedConfigurationProducesTheExpectedWidths() {
        let scrollArea = SetTilesRowMetrics.scrollAreaWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: true
        )
        #expect(scrollArea == 293)

        let tile = SetTilesRowMetrics.tileWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: true,
            visibleTileCount: AppStyle.Layout.setTileVisibleCount
        )
        #expect(abs(tile - 79.1176) < 0.001)
    }

    /// Reserving a column the caller does not fill would shrink the tiles for
    /// nothing, so an unoccupied column costs no width at all — not even its
    /// spacing.
    @Test
    func anUnreservedTrailingColumnCostsNothing() {
        let withoutAccessory = SetTilesRowMetrics.scrollAreaWidth(
            available: available,
            reservedTrailingWidth: 0,
            showsChevron: false
        )
        #expect(withoutAccessory == available)
    }

    @Test
    func theChevronCostsItsColumnPlusOneSpacing() {
        let without = SetTilesRowMetrics.scrollAreaWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: false
        )
        let with = SetTilesRowMetrics.scrollAreaWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: true
        )
        // 8pt column plus its 8pt spacing, pinned rather than re-derived.
        #expect(without - with == 16)
    }

    /// A fractional count reveals part of the next tile, and that peeking tile
    /// still needs a gap in front of it: 3.4 tiles are separated by three gaps,
    /// not two. Charging only for the whole tiles would push the peek off the
    /// viewport edge.
    @Test
    func aFractionalCountChargesSpacingForThePeekingTileToo() {
        let wholeTiles = SetTilesRowMetrics.tileWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: true,
            visibleTileCount: 3
        )
        let withPeek = SetTilesRowMetrics.tileWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: true,
            visibleTileCount: 3.4
        )
        // Three whole tiles share two gaps: (293 - 16) / 3.
        #expect(abs(wholeTiles - 92.3333) < 0.001)
        // The peek adds a third gap: (293 - 24) / 3.4.
        #expect(abs(withPeek - 79.1176) < 0.001)
    }

    /// Guards against a caller passing 0 or a negative count and dividing the
    /// viewport by it.
    @Test(arguments: [CGFloat(0), -1, 0.5])
    func aCountBelowOneIsTreatedAsOneTile(count: CGFloat) {
        let clamped = SetTilesRowMetrics.tileWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: false,
            visibleTileCount: count
        )
        let one = SetTilesRowMetrics.tileWidth(
            available: available,
            reservedTrailingWidth: reservedTrailingWidth,
            showsChevron: false,
            visibleTileCount: 1
        )
        #expect(clamped == one)
    }

    /// The chevron is the overflow signal, so it appears exactly when a set
    /// cannot be shown within the visible count — not at a repeated literal.
    @Test
    func theChevronFollowsTheVisibleTileCount() {
        #expect(!SetTilesRowMetrics.showsChevron(setCount: 3, visibleTileCount: 3.4))
        #expect(SetTilesRowMetrics.showsChevron(setCount: 4, visibleTileCount: 3.4))
        #expect(!SetTilesRowMetrics.showsChevron(setCount: 2, visibleTileCount: 2))
        #expect(SetTilesRowMetrics.showsChevron(setCount: 3, visibleTileCount: 2))
    }
}
