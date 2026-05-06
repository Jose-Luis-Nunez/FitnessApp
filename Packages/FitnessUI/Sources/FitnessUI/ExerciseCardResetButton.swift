import SwiftUI

/// Circular reset button shown on completed exercise cards.
///
/// Hoisted into `FitnessUI` as part of T7-0 so `InactiveCardModelView` in
/// `FitnessPersistenceUI` can reuse it without re-introducing a dependency
/// cycle. Layout constants (size, iconSize) live alongside as
/// `ExerciseCardLayout.ResetButton` (canonical source).
public struct ExerciseCardResetButton: View {
    public let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            CardActionCircleButtonVisual(
                iconSize: ExerciseCardLayout.ResetButton.iconSize,
                discSize: ExerciseCardLayout.ResetButton.size,
                glowSize: ExerciseCardLayout.ResetButton.size
            ) {
                Image("repeat")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
        }
        .buttonStyle(.plain)
    }
}
