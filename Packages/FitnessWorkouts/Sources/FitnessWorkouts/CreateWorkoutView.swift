import SwiftUI
import FitnessCore
import FitnessUI

/// "New Workout" sheet. Mirrors step 1 of the create-exercise flow and reuses
/// the exact same chrome (`OverlaySheetContainer`): a swipeable `BodyIconGallery`
/// of the five muscle groups over a dotted ring, the styled `CardTextField` name
/// input below, and a Cancel | Save action bar. Presented as an overlay by
/// `WorkoutsScreen` (same as the exercise picker), so the backdrop, grabber,
/// scroll, swipe-dismiss and keyboard handling all come from the shared chrome.
struct CreateWorkoutView: View {
    @Binding var workoutName: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var gallerySelection: String = MuscleCategoryGroup.arms.defaultIconName

    private var muscleIcons: [String] {
        MuscleCategoryGroup.allCases.map(\.defaultIconName)
    }

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
                        isPresented = false
                    }
                )
            },
            content: {
                VStack(spacing: 16) {
                    BodyIconGallery(icons: muscleIcons, selection: $gallerySelection)

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
}
