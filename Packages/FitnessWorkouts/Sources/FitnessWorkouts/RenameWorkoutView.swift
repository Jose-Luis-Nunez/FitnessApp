import SwiftUI
import FitnessCore
import FitnessUI
import FitnessResources

struct RenameWorkoutView: View {
    @Binding var workoutName: String
    @Binding var isPresented: Bool
    let workoutToRename: Workout
    let onSave: () -> Void

    private let textColor = AppStyle.Color.white

    var body: some View {
        WorkoutFormSheet(
            title: AppText.workoutRenameTitle,
            isSaveDisabled: workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onSave: onSave,
            isPresented: $isPresented
        ) {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppText.workoutNameShort)
                        .font(.headline)
                        .foregroundColor(textColor)

                    Text(AppText.workoutSetName)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))

                    HStack {
                        TextField("", text: $workoutName, prompt: Text(AppText.workoutName))
                            .foregroundColor(textColor)

                        if !workoutName.isEmpty {
                            Button(action: { workoutName = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppStyle.Color.gray)
                                    .font(AppStyle.Font.tileValue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(AppStyle.Color.backgroundColor)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppStyle.Color.gray, lineWidth: 1)
                    )
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
            }
            .padding(.top, 32)
        }
    }
}
