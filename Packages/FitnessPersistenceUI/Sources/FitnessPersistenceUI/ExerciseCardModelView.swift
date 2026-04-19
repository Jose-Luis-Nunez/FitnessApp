import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessTraining
@_spi(PersistenceUI) import FitnessStorage

/// Pilot-Container für ADR-0001: liest `model.isCompleted` direkt vom `@Model` und
/// reicht in den passenden Variant-View — ohne `ExerciseCardViewModel`-Snapshot.
///
/// Das ist der Schlüssel-Fix für Bug 1: jeder Variant-Recompute basiert auf der
/// live `@Bindable`-Quelle. Wenn der Coordinator nach einem `finish` `model.isCompleted`
/// in der Storage setzt, propagiert SwiftData das in jeden gebundenen View, und der
/// Variant-Switch unten nimmt sofort den `.completed`-Pfad — ohne `syncExercise(...)`,
/// ohne `cardViewModels: [UUID: ExerciseCardViewModel]`-Cache.
///
/// `FitnessCore.resolveCardVariant(...)` wird wiederverwendet (in T7-0 aus
/// `FitnessExercise.ExerciseCardContainerView` nach `FitnessCore` gehoben);
/// kein Code-Duplizieren der Variant-Logik.
///
/// **SPI-Marker**: Die View ist `@_spi(PersistenceUI) public`, weil sie
/// `@Bindable model: ExerciseModel` in der API hat — und `ExerciseModel` ist nur
/// SPI-sichtbar. Aufrufer (T7) müssen `@_spi(PersistenceUI) import FitnessPersistenceUI`
/// deklarieren, das ist die gleiche Compiler-enforced Awareness die wir schon für
/// `FitnessStorage` haben (siehe ADR-0002).
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
