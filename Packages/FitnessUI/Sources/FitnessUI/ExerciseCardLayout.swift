import SwiftUI

/// Shared layout constants for exercise-card and category-tile rendering.
///
/// Hoisted into `FitnessUI` as part of T7-0 to break the
/// `FitnessPersistenceUI → FitnessExercise` dependency cycle that blocks
/// T7a/T7b. The legacy `CategoryTileViewConstants` in `FitnessExercise`
/// and the `InactiveCardView.ResetButton.Constants` enum continue to exist
/// for now (used by their respective views) and will be deleted alongside
/// those views in T8.
public enum ExerciseCardLayout {

    /// Constants for `CategoryTile`-style cards (the muscle-category grid).
    public enum CategoryTile {
        public static let contentPadding: CGFloat = AppStyle.Padding.screenHorizontal
        public static let verticalSpacing: CGFloat = 12
        public static let iconSize: CGFloat = 80
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
