import SwiftUI

/// Circular reset button shown on completed exercise cards.
///
/// Hoisted from `FitnessExercise.InactiveCardView.ResetButton` into
/// `FitnessUI` as part of T7-0 so the new `InactiveCardModelView` in
/// `FitnessPersistenceUI` can reuse it without re-introducing a dependency
/// cycle. Both layout constants (size, iconSize) live alongside as
/// `ExerciseCardLayout.ResetButton` (canonical source).
public struct ExerciseCardResetButton: View {
    public let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Image("repeat")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: ExerciseCardLayout.ResetButton.iconSize,
                    height: ExerciseCardLayout.ResetButton.iconSize
                )
                .foregroundColor(AppStyle.Color.greenGlow)
                .frame(
                    width: ExerciseCardLayout.ResetButton.size,
                    height: ExerciseCardLayout.ResetButton.size
                )
                .background(AppStyle.Color.exerciseCardBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
