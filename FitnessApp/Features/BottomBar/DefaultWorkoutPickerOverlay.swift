import SwiftUI
import FitnessCore
import FitnessUI

/// Floating picker shown when the bottom-bar "Training" tab is tapped while no
/// default workout is set. Lets the user pick which workout becomes the default;
/// the caller then launches straight into that workout's category selection.
///
/// Reuses the app-wide `MiniActionMenuView` pattern (bottom-trailing, tap-out to
/// dismiss) so it matches every other contextual menu in the app.
struct DefaultWorkoutPickerOverlay: View {
    let workouts: [Workout]
    let onPick: (Workout) -> Void
    let onDismiss: () -> Void

    @Environment(\.safeAreaInsets) private var safeAreaInsets

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MiniActionMenuView(
                        title: "Choose default workout",
                        items: workouts.map { workout in
                            MiniActionMenuItem(icon: nil, title: workout.name, isDestructive: false) {
                                onPick(workout)
                            }
                        }
                    )
                    .padding(.trailing, 16)
                }
                .padding(.bottom, safeAreaInsets.bottom - 50)
            }
            .transition(.opacity)
            .zIndex(3)
        }
    }
}
