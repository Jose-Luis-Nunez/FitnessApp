import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessResources
import FitnessUI

public struct ScheduleDayDetailView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let date: Date
    public let workoutDetail: WorkoutDetailData?
    public let exerciseCount: Int

    public init(date: Date, workoutDetail: WorkoutDetailData?, exerciseCount: Int) {
        self.date = date
        self.workoutDetail = workoutDetail
        self.exerciseCount = exerciseCount
    }

    public var body: some View {
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
                Text(verbatim: date.formatted(.dateTime.day().month(.wide).year().locale(locale)))
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)

                if let detail = workoutDetail {
                    let completed = detail.categories.flatMap(\.exercises).filter(\.isCompleted).count
                    let total = detail.categories.flatMap(\.exercises).count
                    Text(AppText.analyticsCompletedExercises(completed: completed, total: total))
                        .font(AppStyle.Font.detailCaption)
                        .foregroundColor(appColorTheme.accent.glow.opacity(0.7))
                }
            }

            Spacer()

            if workoutDetail != nil {
                completionBadge
            }
        }
    }

    @ViewBuilder
    private var completionBadge: some View {
        let completed = (workoutDetail?.categories ?? []).flatMap(\.exercises).filter(\.isCompleted).count
        let total = (workoutDetail?.categories ?? []).flatMap(\.exercises).count
        let pct = total > 0 ? Int(round(Double(completed) / Double(total) * 100)) : 0

        Text(verbatim: "\(pct)%")
            .font(AppStyle.Font.detailBadge)
            .foregroundColor(pct == 100 ? appColorTheme.accent.glow : AppStyle.Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(pct == 100 ? appColorTheme.accent.glow.opacity(0.2) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pct == 100 ? appColorTheme.accent.glow.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }

    // MARK: - Category Section

    private func categorySection(_ category: CategoryDetailData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.category.localizedName)
                .font(AppStyle.Font.detailCategory)
                .foregroundColor(appColorTheme.accent.glow)

            ForEach(category.exercises, id: \.exercise.id) { exerciseDetail in
                exerciseRow(exerciseDetail)
            }
        }
    }

    private func exerciseRow(_ detail: ExerciseDetailData) -> some View {
        HStack {
            Text(verbatim: detail.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white.opacity(detail.isCompleted ? 1 : 0.5))

            Spacer()

            Group {
                if detail.isCompleted {
                    Text(AppText.actionDone)
                } else {
                    Text(verbatim: "—")
                }
            }
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(detail.isCompleted ? appColorTheme.accent.glow : Color.white.opacity(0.3))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(detail.isCompleted ? appColorTheme.accent.glow.opacity(0.15) : Color.white.opacity(0.04))
                )
        }
        .padding(.leading, 12)
    }

    // MARK: - States

    private var partialDataView: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundColor(appColorTheme.accent.glow.opacity(0.6))
            Text(AppText.exerciseCountLogged(count: exerciseCount))
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .foregroundColor(Color.white.opacity(0.25))
            Text(AppText.trainingNoneDay)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}
