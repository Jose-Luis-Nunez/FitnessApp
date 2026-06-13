import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessTraining
@_spi(PersistenceUI) import FitnessStorage

/// Container for ADR-0001: reads `model.isCompleted` directly from the `@Model`
/// and forwards into the matching variant view — without a snapshot ViewModel.
///
/// Every variant recompute is based on the live `@Bindable` source. When the
/// coordinator sets `model.isCompleted` in storage after a `finish`, SwiftData
/// propagates that into every bound view, and the variant switch below
/// immediately takes the `.completed` path — without a manual sync step.
///
/// `FitnessCore.resolveCardVariant(...)` is reused (hoisted into `FitnessCore`
/// in T7-0); no code duplication of the variant logic.
///
/// **SPI marker**: The view is `@_spi(PersistenceUI) public`, because it has
/// `@Bindable model: ExerciseModel` in its API — and `ExerciseModel` is only
/// SPI-visible. Callers must declare
/// `@_spi(PersistenceUI) import FitnessPersistenceUI`; that is the same
/// compiler-enforced awareness we already have for `FitnessStorage`
/// (see ADR-0002).
@_spi(PersistenceUI)
public struct ExerciseCardModelView: View {
    @Bindable public var model: ExerciseModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel
    public var activeSetViewModel: ActiveSetViewModel
    public let onStart: ((Exercise) -> Void)?
    public let onReset: ((Exercise) -> Void)?
    public let isActiveSetVisible: Bool
    public let isResetEnabled: Bool
    public let isInProgress: Bool

    public init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        activeSetViewModel: ActiveSetViewModel,
        onStart: ((Exercise) -> Void)?,
        onReset: ((Exercise) -> Void)?,
        isActiveSetVisible: Bool,
        isResetEnabled: Bool,
        isInProgress: Bool = false
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.activeSetViewModel = activeSetViewModel
        self.onStart = onStart
        self.onReset = onReset
        self.isActiveSetVisible = isActiveSetVisible
        self.isResetEnabled = isResetEnabled
        self.isInProgress = isInProgress
    }

    public var body: some View {
        let variant = resolveCardVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: isActiveSetVisible,
            activeExerciseId: activeSetViewModel.currentExercise?.id,
            exerciseId: model.id
        )

        switch variant {
        case .completed:
            InactiveCardModelView(
                model: model,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel,
                onReset: onReset,
                isResetEnabled: isResetEnabled
            )
            .accessibilityIdentifier(ExerciseCardIDs.completedCard(model.id))
        case .active:
            ActiveCardModelView(
                model: model,
                onEdit: onEdit,
                isEditable: isEditable,
                analyticsViewModel: analyticsViewModel
            )
            .accessibilityIdentifier(ExerciseCardIDs.activeCard(model.id))
        case .idle:
            IdleActiveCardModelView(
                model: model,
                analyticsViewModel: analyticsViewModel,
                onEdit: onEdit,
                isEditable: isEditable,
                onStart: onStart,
                isInProgress: isInProgress
            )
            .accessibilityIdentifier(ExerciseCardIDs.idleCard(model.id))
        }
    }
}
