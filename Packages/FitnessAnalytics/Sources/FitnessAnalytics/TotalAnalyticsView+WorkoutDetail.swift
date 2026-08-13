import FitnessCore
import FitnessUI
import SwiftUI

extension TotalAnalyticsView {

    var workoutDetailView: some View {
        AnalyticsDetailSection(shouldShowIndicator: shouldShowScrollIndicator()) {
            AnalyticsDetailHeader(
                title: "Last Workout",
                subtitle: workoutDetailData.map { DateFormatter.germanShort.string(from: $0.date) },
                onBack: { showWorkoutDetail = false }
            )
        } content: {
            workoutDetailContent
        }
    }

    private var workoutDetailContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if let workoutDetail = workoutDetailData {
                ForEach(workoutDetail.categories, id: \.category) { categoryDetail in
                    categoryDetailSection(categoryDetail: categoryDetail)
                }
            } else {
                Text("No workout data available")
                    .font(AppStyle.Font.pickerAction)
                    .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    func categoryDetailSection(categoryDetail: CategoryDetailData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(categoryDetail.category.displayName)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(appColorTheme.accent.glow)

            ForEach(categoryDetail.exercises, id: \.exercise.id) { exerciseDetail in
                exerciseDetailRow(exerciseDetail: exerciseDetail)
            }
        }
    }

    @ViewBuilder
    func exerciseDetailRow(exerciseDetail: ExerciseDetailData) -> some View {
        HStack {
            Text(exerciseDetail.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(appColorTheme.accent.glow)

            Spacer()

            Text(exerciseDetail.isCompleted ? "Done" : "Not Started")
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(exerciseDetail.isCompleted ? appColorTheme.accent.glow : appColorTheme.accent.glow.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(exerciseDetail.isCompleted ? appColorTheme.accent.glow.opacity(0.2) : appColorTheme.accent.glow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(appColorTheme.accent.glow.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.leading, 12)
    }

    func shouldShowScrollIndicator() -> Bool {
        guard let workoutDetail = workoutDetailData else { return false }

        let totalExercises = workoutDetail.categories.reduce(0) { total, category in
            total + category.exercises.count
        }

        return totalExercises > 4
    }
}
