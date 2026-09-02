import SwiftUI

/// Shared layout constants for exercise-card and category-tile rendering.
///
/// Hoisted into `FitnessUI` as part of T7-0 to break the
/// `FitnessPersistenceUI → FitnessExercise` dependency cycle. Post-T8d the
/// canonical card stack lives in `FitnessPersistenceUI`
/// (`InactiveCardModelView` / `ActiveCardModelView` / `IdleActiveCardModelView`);
/// `ExerciseCardLayout` is the single source of truth for the layout
/// constants those views consume.
public enum ExerciseCardLayout {

    /// Constants for `CategoryTile`-style cards (the muscle-category grid).
    public enum CategoryTile {
        public static let gridSpacing: CGFloat = 10
        public static let gridHorizontalPadding: CGFloat = AppStyle.Padding.screenHorizontal
        public static let contentPadding: CGFloat = AppStyle.Padding.screenHorizontal
        public static let contentSpacing: CGFloat = 8
        public static let verticalPadding: CGFloat = 12
        public static let verticalSpacing: CGFloat = 6
        public static let height: CGFloat = 180
        public static let footerSpacerHeight: CGFloat = 3
        public static let headerBadgeSize: CGFloat = 32
        public static let headerBadgeInnerSize: CGFloat = 26
        public static let iconSize: CGFloat = 80
        public static let iconArtworkSize: CGFloat = 100
        public static let iconGlowSize: CGFloat = iconSize * 0.9
        public static let iconGlowBlurRadius: CGFloat = 15
        public static let progressWidth: CGFloat = 90
        public static let minimumTextScale: CGFloat = 0.8
    }

    /// Constants for the in-line progress bar inside category tiles.
    public enum ProgressBar {
        public static let height: CGFloat = 9
    }

    /// Constants for the set-tile row on the expanded completed card.
    public enum SetTiles {
        /// Height of the set-tile row. Sized so the three stacked lines
        /// (set label, value, reps) plus their padding fit without the block
        /// crowding the top edge — the previous 60pt left the content taller
        /// than its box, which is why the tile read as top-weighted.
        ///
        /// Shared by the completed card and the idle card's expanded "Last run"
        /// row (which also has to clear its trailing coaching rail), so the two
        /// set-tile rows cannot drift apart. Replaces the former
        /// `AppStyle.Layout.idleLastRunDetailsHeight`, which held the same
        /// number for the same reason.
        public static let rowHeight: CGFloat = 72
    }

    /// The trailing control column shared by the completed card's checkmark and
    /// the reset button below it.
    ///
    /// Both controls are pinned to the same card edge, so they only line up if
    /// they are centred in boxes of the same width. They were not: the checkmark
    /// sits in a 44pt tap-target column while the reset button is only as wide
    /// as its 40pt disc, which put their centres 2pt apart. Anything placed in
    /// this column must claim `columnWidth`, not its own intrinsic width.
    public enum TrailingControl {
        public static let columnWidth: CGFloat = AppStyle.Layout.minimumTapTargetSize
    }

    /// Constants for the coaching increase-tile row on the idle card.
    public enum IncreaseTiles {
        /// Height of the increase-tile row. The row derives its tile width inside a
        /// `GeometryReader`, which claims all offered height, so the caller has
        /// to state it — the same arrangement `SetTiles.rowHeight` serves.
        /// Sized against the tile's tallest state: the summary block and two
        /// three-line sessions. The tiles are narrower than when this number was
        /// chosen, so the lines scale sooner rather than overflow — check this
        /// value again if the summary ever grows a line.
        public static let rowHeight: CGFloat = 208
    }

    /// Constants for the circular coaching-tip badge on the idle card.
    ///
    /// Shares `ResetButton.size` on purpose — it is the same 40pt card-action
    /// circle — but carries its own glyph size. It used to borrow
    /// `ResetButton.iconSize` too, which is wrong: that value is a *width* tuned
    /// for the 3:2 `repeat` artwork, while `tip_coaching_2` is square. The same
    /// number therefore renders half again as tall here, and every adjustment to
    /// the reset glyph silently resized this one.
    public enum CoachingTip {
        public static let iconSize: CGFloat = 24
    }

    /// Constants for the circular reset button on completed cards.
    public enum ResetButton {
        public static let size: CGFloat = 40
        /// Width of the repeat glyph. Deliberately a width, not a box: the
        /// `repeat` artwork is 3:2, and `CardActionCircleButtonVisual` fits its
        /// glyph into a *square* `iconSize`, so the width decides the scale and
        /// the rendered height is only two thirds of this number. Earlier values
        /// were read as a height and came out a third smaller than intended.
        ///
        /// 32pt renders the glyph at ~32 x 21pt. The largest 3:2 rectangle that
        /// fits inside the 40pt ring is ~33 x 22pt, so this is essentially the
        /// ceiling — going higher pushes the glyph onto the hairline.
        public static let iconSize: CGFloat = 32
    }
}
