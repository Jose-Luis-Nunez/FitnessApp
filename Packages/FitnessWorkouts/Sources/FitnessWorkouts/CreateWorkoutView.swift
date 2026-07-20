import SwiftUI
import FitnessCore
import FitnessUI

/// "New Workout" sheet. Mirrors the Create-Exercise header and shared form chrome,
/// but only collects the required workout name and type.
struct CreateWorkoutView: View {
    @Binding var workoutName: String
    @Binding var workoutType: WorkoutType?
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var selectedIconName = WorkoutTileArtwork.assetName

    private var isSaveDisabled: Bool {
        workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || workoutType == nil
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
                    },
                    saveAccessibilityIdentifier: WorkoutIDs.createSaveButton
                )
            },
            content: {
                VStack(spacing: AppStyle.Padding.card) {
                    workoutHeader
                    workoutNameField
                    workoutTypePicker
                }
            }
        )
    }

    private var workoutHeader: some View {
        VStack(spacing: ExerciseCardLayout.CategoryTile.verticalSpacing) {
            BodyIconGallery(
                icons: [WorkoutTileArtwork.assetName],
                selection: $selectedIconName
            )

            Text("New Workout")
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
                .accessibilityIdentifier(WorkoutIDs.createTitle)
        }
        .padding(.bottom, AppStyle.Padding.card)
    }

    private var workoutNameField: some View {
        CardTextField(
            label: "Workout Name",
            placeholder: "e.g. Pull, Push",
            text: $workoutName,
            isFocused: $isNameFocused,
            accessibilityIdentifier: WorkoutIDs.createNameField
        )
    }

    private var workoutTypePicker: some View {
        VStack(alignment: .leading, spacing: ExerciseCardLayout.CategoryTile.verticalSpacing) {
            Text("Workout Type")
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))

            Picker("Workout Type", selection: $workoutType) {
                Text("Select Workout Type").tag(WorkoutType?.none)
                ForEach(WorkoutType.allCases) { type in
                    Text(type.displayName).tag(type as WorkoutType?)
                }
            }
            .pickerStyle(.menu)
            .tint(AppStyle.Color.white)
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
