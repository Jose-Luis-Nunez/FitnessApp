import SwiftUI

/// Slim horizontal progress bar used by category tiles.
///
/// Hoisted from `FitnessExercise.CategoryTileView` into `FitnessUI` as
/// part of T7-0 so the new `CategoryTileModelView` in `FitnessPersistenceUI`
/// can render it without re-introducing a dependency cycle. Uses the
/// canonical `ExerciseCardLayout.ProgressBar.height` constant.
public struct ProgressBar: View {
    public let progress: Double
    public let totalWidth: CGFloat

    @AppStorage(DefaultIconColorScheme.storageKey)
    private var iconColorScheme: DefaultIconColorScheme = .green

    private var fillColor: Color { iconColorScheme.progressFillColor }
    private var trackColor: Color { iconColorScheme.progressTrackColor }

    public init(progress: Double, totalWidth: CGFloat) {
        self.progress = progress
        self.totalWidth = totalWidth
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            trackView
            progressView
        }
        .frame(width: totalWidth, height: ExerciseCardLayout.ProgressBar.height)
    }

    private var trackView: some View {
        Capsule()
            .fill(trackColor)
            .frame(width: totalWidth, height: ExerciseCardLayout.ProgressBar.height)
    }

    private var progressView: some View {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        return Capsule()
            .fill(fillColor)
            .frame(
                width: CGFloat(clampedProgress) * totalWidth,
                height: ExerciseCardLayout.ProgressBar.height
            )
    }
}
