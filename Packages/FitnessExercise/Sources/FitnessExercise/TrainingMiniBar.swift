import Foundation
import FitnessCore
import FitnessTraining
import Factory

/// Shared answer to "is the training mini bar showing, and for which exercise?".
///
/// It lives in this package rather than next to the view so the scene rules stay
/// with the router they depend on, and so they can be exercised without a view.
///
/// How much room the bar's plate takes is deliberately *not* answered here.
/// That distance is published by the bar itself as
/// `UIOverlayState.trainingMiniBarClearance`, because only the bar can measure a
/// view it owns. Hand-measured constants for the same distance used to live in
/// this type and drifted apart from the rendered plate the moment the bar's
/// spacing changed — with content silently vanishing under an opaque plate as
/// the only symptom.
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
