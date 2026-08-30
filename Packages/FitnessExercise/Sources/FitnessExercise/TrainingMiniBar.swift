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

    /// The mini bar is a way *back into* training, so it stays hidden while the
    /// training sheet itself is up, and on the scenes that are not part of the
    /// workout drill-down.
    ///
    /// Ordered most recently opened first — the bar opens on that one and pages
    /// towards older sessions.
    /// The cache is the only cross-category owner of training state, so the
    /// recency answer comes from it rather than from a single coordinator.
    ///
    /// It is a parameter rather than a container lookup so the scene rules can be
    /// exercised against a stub. Production callers use the default; the seam
    /// exists for the tests.
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
