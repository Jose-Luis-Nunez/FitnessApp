import SwiftUI
import FitnessCore
import FitnessUI

struct CreateWorkoutView: View {
    @Binding var workoutName: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    var viewModel: WorkoutsViewModel

    private let textColor = AppStyle.Color.white

    var body: some View {
        WorkoutFormSheet(
            title: "Neues Workout",
            isSaveDisabled: workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onSave: onSave,
            isPresented: $isPresented
        ) {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.headline)
                        .foregroundColor(textColor)

                    Text("Set your workout name")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))

                    TextField("Workout Name", text: $workoutName)
                        .padding(12)
                        .background(AppStyle.Color.backgroundColor)
                        .cornerRadius(10)
                        .foregroundColor(textColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppStyle.Color.gray, lineWidth: 1)
                        )
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Muskelgruppen")
                            .font(.headline)
                            .foregroundColor(textColor)

                        Text("Wähle die Kategorien für dein Workout")
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.7))
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)

                    muscleGroupsGrid
                }
            }
            .padding(.top, 32)
        }
    }

    private var muscleGroupsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
                MuscleGroupTile(
                    group: group,
                    isSelected: viewModel.isMuscleGroupSelected(group),
                    onTap: {
                        viewModel.toggleMuscleGroup(group)
                    }
                )
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
}

struct MuscleGroupTile: View {
    let group: MuscleCategoryGroup
    let isSelected: Bool
    let onTap: () -> Void

    private let iconSize: CGFloat = 60

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppStyle.Color.green.opacity(0.3))
                            .frame(width: iconSize * 0.9, height: iconSize * 0.9)
                            .blur(radius: 10)
                            .opacity(0.6)
                    }

                    Image(group.defaultIconName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: iconSize, height: iconSize, alignment: group.iconAlignment)
                        .clipped()
                        .foregroundColor(isSelected ? AppStyle.Color.green : AppStyle.Color.white)
                }
                .frame(width: iconSize, height: iconSize)

                Text(group.displayName)
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(isSelected ? AppStyle.Color.green : AppStyle.Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? AppStyle.Color.green.opacity(0.1) : AppStyle.Color.backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? AppStyle.Color.green : AppStyle.Color.gray,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
