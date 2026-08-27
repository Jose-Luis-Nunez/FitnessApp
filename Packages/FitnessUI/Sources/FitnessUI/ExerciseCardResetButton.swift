import SwiftUI

/// Circular reset button shown on completed exercise cards.
///
/// Hoisted into `FitnessUI` as part of T7-0 so `InactiveCardModelView` in
/// `FitnessPersistenceUI` can reuse it without re-introducing a dependency
/// cycle. Layout constants (size, iconSize) live alongside as
/// `ExerciseCardLayout.ResetButton` (canonical source).
public struct ExerciseCardResetButton: View {
    public let onTap: () -> Void
    private let image: Image

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        self.image = Image("repeat")
    }

    init(image: Image, onTap: @escaping () -> Void) {
        self.onTap = onTap
        self.image = image
    }

    public var body: some View {
        Button(action: onTap) {
            CardActionCircleButtonVisual(
                iconSize: ExerciseCardLayout.ResetButton.iconSize,
                discSize: ExerciseCardLayout.ResetButton.size,
                frameSize: ExerciseCardLayout.ResetButton.size,
                surface: .filled()
            ) {
                image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
        }
        .buttonStyle(.plain)
    }
}
