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

    /// Constants for the circular reset button on completed cards.
    public enum ResetButton {
        public static let size: CGFloat = 40
        public static let iconSize: CGFloat = 32
    }
}
