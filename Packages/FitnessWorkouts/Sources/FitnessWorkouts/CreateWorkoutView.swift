import SwiftUI
import FitnessCore
import FitnessUI

/// "New Workout" sheet. Mirrors step 1 of the create-exercise flow and reuses
/// the exact same chrome (`OverlaySheetContainer`): a preview of the generic
/// workout artwork, a persisted workout-type dropdown, the styled
/// `CardTextField` name input, and a Cancel | Save action bar. Presented as an overlay by
/// `WorkoutsScreen` (same as the exercise picker), so the backdrop, grabber,
/// scroll, swipe-dismiss and keyboard handling all come from the shared chrome.
struct CreateWorkoutView: View {
    @Binding var workoutName: String
    @Binding var workoutType: WorkoutType
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @FocusState private var isNameFocused: Bool
    private var isSaveDisabled: Bool {
        workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            backgroundColor: AppStyle.Color.backgroundColor,
            expandsToTop: true,
            onCancel: {},
            actions: {
                ExercisePickerActionButtons(
                    cancelColor: AppStyle.Color.green,
                    saveDisabled: isSaveDisabled,
                    onCancel: { isPresented = false },
                    onSave: {
                        isNameFocused = false
                        onSave()
                    }
                )
            },
            content: {
                VStack(spacing: AppStyle.Padding.card) {
                    CategoryTileArtworkStage(alignment: workoutType.iconAlignment) {
                        Image(WorkoutTileArtwork.assetName)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                    }

                    workoutTypePicker

                    CardTextField(
                        label: "Name",
                        placeholder: "Workout Name",
                        text: $workoutName,
                        isFocused: $isNameFocused
                    )
                }
            }
        )
    }

    private var workoutTypePicker: some View {
        VStack(alignment: .leading, spacing: ExerciseCardLayout.CategoryTile.verticalSpacing) {
            Text("Workout-Typ")
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))

            Picker("Workout-Typ", selection: $workoutType) {
                ForEach(WorkoutType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .tint(AppStyle.Color.greenMint)
            .accessibilityIdentifier(WorkoutIDs.createTypePicker)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Padding.cardVertical)
        .appDarkSurface(
            backgroundColor: AppStyle.Color.idleCardBackground,
            in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
        )
    }
}
