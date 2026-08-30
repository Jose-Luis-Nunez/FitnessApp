import Foundation
import FitnessCore
import FitnessTraining
import Factory

/// Shared answer to "is the training mini bar showing, and for which exercise?".
///
/// It lives here rather than next to the view because two unrelated places need
/// it: the bottom bar renders the mini bar, and page chrome that sits at the same
/// height (the Overview/List toggle) has to step out of the way of the plate the
/// mini bar brings with it.
@MainActor
public enum TrainingMiniBar {
    /// Vertical room the mini bar and its plate claim above the tab row. Page
    /// chrome anchored to the bottom adds this to its own bottom inset while a
    /// mini bar is showing, otherwise the plate would cut through it.
    ///
    /// Depends on the count because the paging controls only exist from two
    /// running exercises on: with a single one the bar is exactly what it was
    /// before this feature. Both values are measured against the rendered plate
    /// at the default text size, not estimated.
    ///
    /// Known duplication: the bar itself derives the same distance at runtime
    /// from the measured mini-bar height (`MiniBarHeightKey` in
    /// `BottomMenuBarView`), because it can measure a view it owns while this
    /// helper cannot — it is consumed by a different package. Changing the bar's
    /// spacing constants or the title font desynchronises the two and the plate
    /// will cut into the Overview/List toggle, so re-measure both values when
    /// touching either.
    public static func clearance(for count: Int) -> CGFloat {
        count > 1 ? pagingClearance : singleClearance
    }

    private static let singleClearance: CGFloat = 63
    private static let pagingClearance: CGFloat = 87


    /// The mini bar is a way *back into* training, so it stays hidden while the
    /// training sheet itself is up, and on the scenes that are not part of the
    /// workout drill-down.
    ///
    /// Ordered most recently opened first — the bar opens on that one and pages
    /// towards older sessions.
    /// The cache is the only cross-category owner of training state, so the
    /// recency answer comes from it rather than from a single coordinator. It is
    /// a parameter so a caller that already holds an injected cache passes its
    /// own — otherwise a view under test would drive one cache while this helper
    /// silently resolved another from the container.
    public static func targets(
        router: AppRouter,
        cache: TrainingCoordinatorCaching = Container.shared.trainingCoordinatorCache()
    ) -> [ActiveTrainingTarget] {
        guard router.trainingPresentation == nil else { return [] }
        switch router.currentScene {
        case .home, .category:
            return cache.activeTrainings
        case .workouts, .analytics, .schedule, .profile:
            return []
        }
    }
}
