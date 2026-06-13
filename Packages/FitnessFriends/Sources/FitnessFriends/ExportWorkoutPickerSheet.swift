import SwiftUI
import FitnessCore
import FitnessUI
import FitnessWorkouts

struct ExportWorkoutPickerSheet: View {
    @Binding var isPresented: Bool
    let workouts: [Workout]
    let onSelect: (Workout) -> Void
    let exerciseCount: (Workout) -> Int
    @Binding var workoutToShare: WorkoutShareItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                Text("Export Workout")
                    .font(AppStyle.Font.sheetTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, AppStyle.Padding.sectionSpacing)

                if workouts.isEmpty {
                    Text("No workouts available.")
                        .font(AppStyle.Font.profileCardTitle)
                        .foregroundColor(AppStyle.Color.greenLight)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(workouts) { workout in
                            WorkoutTileView(
                                workout: workout,
                                isDefault: false,
                                exerciseCount: exerciseCount(workout),
                                onTap: { onSelect(workout) }
                            )
                            .accessibilityIdentifier("id_friends_export_workout_\(workout.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.sectionSpacing)
            .padding(.bottom, AppStyle.Padding.sectionSpacing)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                Spacer()
                Button("Cancel") { isPresented = false }
                    .foregroundColor(AppStyle.Color.white)
                    .font(AppStyle.Font.pickerAction)
                    .padding(5)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(AppStyle.Color.green)
                    .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                    .accessibilityIdentifier("id_friends_export_cancel")
                Spacer()
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.sectionSpacing)
            .background(AppStyle.Color.backgroundColor)
        }
        .preferredColorScheme(.dark)
        .presentationBackground(AppStyle.Color.backgroundColor)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $workoutToShare) { item in
            ShareSheet(items: [item.fileURL ?? item.json as Any], tempFileURL: item.fileURL)
        }
    }
}
