import SwiftUI

struct ScheduleDayDetailView: View {
    let date: Date
    let workoutDetail: WorkoutDetailData?
    let exerciseCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if let detail = workoutDetail, !detail.categories.isEmpty {
                ForEach(detail.categories, id: \.category) { categoryDetail in
                    categorySection(categoryDetail)
                }
            } else if exerciseCount > 0 {
                partialDataView
            } else {
                emptyState
            }
        }
        .padding(AppStyle.Padding.card)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .fill(Color.white.opacity(AppStyle.Opacity.subtleBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(DateFormatter.germanMedium.string(from: date))
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)

                if let detail = workoutDetail {
                    let completed = detail.categories.flatMap(\.exercises).filter(\.isCompleted).count
                    let total = detail.categories.flatMap(\.exercises).count
                    Text("\(completed)/\(total) Exercises")
                        .font(AppStyle.Font.detailCaption)
                        .foregroundColor(AppStyle.Color.greenGlow.opacity(0.7))
                }
            }

            Spacer()

            if workoutDetail != nil {
                completionBadge
            }
        }
    }

    private var completionBadge: some View {
        let detail = workoutDetail!
        let completed = detail.categories.flatMap(\.exercises).filter(\.isCompleted).count
        let total = detail.categories.flatMap(\.exercises).count
        let pct = total > 0 ? Int(round(Double(completed) / Double(total) * 100)) : 0

        return Text("\(pct)%")
            .font(AppStyle.Font.detailBadge)
            .foregroundColor(pct == 100 ? AppStyle.Color.greenGlow : AppStyle.Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(pct == 100 ? AppStyle.Color.greenGlow.opacity(0.2) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pct == 100 ? AppStyle.Color.greenGlow.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }

    // MARK: - Category Section

    private func categorySection(_ category: CategoryDetailData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.category.displayName)
                .font(AppStyle.Font.detailCategory)
                .foregroundColor(AppStyle.Color.greenGlow)

            ForEach(category.exercises, id: \.exercise.id) { exerciseDetail in
                exerciseRow(exerciseDetail)
            }
        }
    }

    private func exerciseRow(_ detail: ExerciseDetailData) -> some View {
        HStack {
            Text(detail.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white.opacity(detail.isCompleted ? 1 : 0.5))

            Spacer()

            Text(detail.isCompleted ? "Done" : "—")
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(detail.isCompleted ? AppStyle.Color.greenGlow : Color.white.opacity(0.3))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(detail.isCompleted ? AppStyle.Color.greenGlow.opacity(0.15) : Color.white.opacity(0.04))
                )
        }
        .padding(.leading, 12)
    }

    // MARK: - States

    private var partialDataView: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") logged")
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .foregroundColor(Color.white.opacity(0.25))
            Text("No training on this day")
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}
