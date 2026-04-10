import SwiftUI
import FitnessCore
import FitnessUI

public enum CategoryTileViewConstants {
    public enum CategoryTile {
        public static let contentPadding: CGFloat = AppStyle.Padding.screenHorizontal
        public static let verticalSpacing: CGFloat = 12
        public static let iconSize: CGFloat = 80
    }

    public enum ProgressBar {
        public static let height: CGFloat = 9
    }
}

fileprivate struct ExerciseInfo {
    let total: Int
    let active: Int
    let completed: Int
    let isCompleted: Bool
    let progress: Double
    let hasActiveSet: Bool

    init(total: Int, active: Int, hasActiveSet: Bool) {
        self.total = total
        self.active = active
        self.completed = max(0, total - active)
        self.isCompleted = (active == 0 && total > 0 && !hasActiveSet)
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
        self.hasActiveSet = hasActiveSet
    }
}

public struct CategoryTileView: View {
    public let group: MuscleCategoryGroup
    public var viewModel: MuscleCategorySelectionViewModel

    public init(group: MuscleCategoryGroup, viewModel: MuscleCategorySelectionViewModel) {
        self.group = group
        self.viewModel = viewModel
    }

    public var body: some View {
        let exerciseInfo = createExerciseInfo()

        CardBackground(
            backgroundColor: AppStyle.Color.exerciseCardBackground,
            useGlassEffect: true,
            addPadding: false
        ) {
            VStack(spacing: 8) {
                HStack {
                    Text(group.displayName)
                        .font(AppStyle.Font.categoryTileTitle)
                        .foregroundColor(exerciseInfo.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if exerciseInfo.isCompleted {
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 32, height: 32)

                            Image(systemName: "checkmark")
                                .font(AppStyle.Font.categoryTileCount)
                                .foregroundColor(AppStyle.Color.exerciseCardBackground)
                        }
                    } else if exerciseInfo.total == 0 {
                        ZStack {
                            Circle()
                                .fill(AppStyle.Color.greenGlow)
                                .frame(width: 32, height: 32)

                            Image(systemName: "plus")
                                .font(AppStyle.Font.categoryTileBadge)
                                .foregroundColor(AppStyle.Color.greenBlack)
                        }
                    } else {
                        Spacer()
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)

                ZStack {
                    Circle()
                        .fill(AppStyle.Color.greenBlack)
                        .frame(
                            width: CategoryTileViewConstants.CategoryTile.iconSize * 0.9,
                            height: CategoryTileViewConstants.CategoryTile.iconSize * 0.9
                        )
                        .blur(radius: 15)
                        .opacity(0.5)

                    Image(group.defaultIconName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100, alignment: group.iconAlignment)
                        .clipped()
                        .foregroundColor(AppStyle.Color.white)
                }
                .frame(width: CategoryTileViewConstants.CategoryTile.iconSize, height: CategoryTileViewConstants.CategoryTile.iconSize)

                Spacer()
                    .frame(height: 3)

                if exerciseInfo.total > 0 {
                    HStack(spacing: 8) {
                        if !exerciseInfo.isCompleted {
                            ProgressBar(
                                progress: exerciseInfo.progress,
                                totalWidth: 90
                            )
                            .frame(height: CategoryTileViewConstants.ProgressBar.height)
                        }

                        Spacer()

                        Text("\(exerciseInfo.completed) of \(exerciseInfo.total)")
                            .font(AppStyle.Font.categoryTileProgress)
                            .foregroundColor(exerciseInfo.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)
                } else {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(" ")
                            .font(AppStyle.Font.categoryTileProgress)
                            .foregroundColor(.clear)
                    }
                    .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)
                }
            }
            .padding(.vertical, 12)
            .overlay(
                exerciseInfo.isCompleted ?
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppStyle.Color.green.opacity(0.3))
                    : nil
            )
        }
    }

    private func createExerciseInfo() -> ExerciseInfo {
        let count = viewModel.getExerciseCount(for: group) ?? (0, 0)
        let hasActiveSet = viewModel.hasActiveSetForCategory(group)
        return ExerciseInfo(total: count.total, active: count.active, hasActiveSet: hasActiveSet)
    }
}

public struct ProgressBar: View {
    public let progress: Double
    public let totalWidth: CGFloat

    private let fillColor = AppStyle.Color.greenGlow
    private let trackColor = AppStyle.Color.progressTrack

    public init(progress: Double, totalWidth: CGFloat) {
        self.progress = progress
        self.totalWidth = totalWidth
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            trackView
            progressView
        }
        .frame(width: totalWidth, height: CategoryTileViewConstants.ProgressBar.height)
    }

    private var trackView: some View {
        Capsule()
            .fill(trackColor)
            .frame(width: totalWidth, height: CategoryTileViewConstants.ProgressBar.height)
    }

    private var progressView: some View {
        let clampedProgress = min(max(progress, 0.0), 1.0)
        return Capsule()
            .fill(fillColor)
            .frame(
                width: CGFloat(clampedProgress) * totalWidth,
                height: CategoryTileViewConstants.ProgressBar.height
            )
    }
}
