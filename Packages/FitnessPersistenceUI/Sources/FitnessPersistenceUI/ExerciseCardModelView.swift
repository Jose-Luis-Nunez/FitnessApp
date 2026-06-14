import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessTraining
import FitnessUI
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

    /// When `true` the (idle) card shows a leading radio button and tapping
    /// anywhere on it toggles selection (deactivate/activate multi-select mode)
    /// instead of its normal edit/start gestures.
    public let isSelectable: Bool
    public let isSelected: Bool
    public let onToggleSelection: ((Exercise) -> Void)?
    /// Long-press on an idle card (only when not already in selection mode) —
    /// the host uses it to start the deactivate selection with this card ticked.
    public let onLongPress: ((Exercise) -> Void)?

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
        isInProgress: Bool = false,
        isSelectable: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: ((Exercise) -> Void)? = nil,
        onLongPress: ((Exercise) -> Void)? = nil
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
        self.isSelectable = isSelectable
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
        self.onLongPress = onLongPress
    }

    public var body: some View {
        let variant = resolveCardVariant(
            isCompleted: model.isCompleted,
            isActiveSetVisible: isActiveSetVisible,
            activeExerciseId: activeSetViewModel.currentExercise?.id,
            exerciseId: model.id
        )
        // The actively-training card must stay fully interactive — never selectable.
        let isActiveTraining = isVariantActive(variant)

        if isSelectable && !isActiveTraining {
            // The idle card renders its own leading radio + hides play/tip, so it
            // keeps the same full width as every other card. Inner controls are
            // disabled; a transparent overlay turns the whole row into one tap target.
            cardVariant(variant)
                .allowsHitTesting(false)
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onToggleSelection?(model.toDomain()) }
                )
                // Inset by the card padding so the tint matches the visible card
                // background (CardShell insets it by `AppStyle.Padding.card`).
                .selectedMilkyAppearance(isSelected: isSelected, horizontalInset: AppStyle.Padding.card)
        } else if !isActiveTraining, case .idle = variant, let onLongPress {
            // Long-press an idle card to start the deactivate selection — with a
            // medium haptic, like the iOS home-screen long-press.
            cardVariant(variant)
                .onLongPressGesture(minimumDuration: 0.4) {
                    Haptics.impact(.medium)
                    onLongPress(model.toDomain())
                }
        } else {
            cardVariant(variant)
        }
    }

    @ViewBuilder
    private func cardVariant(_ variant: CardVariant) -> some View {
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
                isEditable: isEditable && !isSelectable,
                onStart: onStart,
                isInProgress: isInProgress,
                isSelectionMode: isSelectable,
                isSelected: isSelected
            )
            .accessibilityIdentifier(ExerciseCardIDs.idleCard(model.id))
        }
    }

    private func isVariantActive(_ variant: CardVariant) -> Bool {
        if case .active = variant { return true }
        return false
    }
}
