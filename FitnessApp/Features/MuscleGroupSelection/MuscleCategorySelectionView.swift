import SwiftUI

private enum Constants {
    static let horizontalPadding: CGFloat = 15
    static let verticalSpacing: CGFloat = 10
    static let titleTopPadding: CGFloat = 10
    static let spacerHeight: CGFloat = 30
    static let topPadding: CGFloat = 5

    enum CategoryTile {
        static let barWidth: CGFloat = 120
        static let chipVerticalPadding: CGFloat = 10
        static let contentPadding: CGFloat = 15
        static let itemSpacing: CGFloat = 12
        static let verticalSpacing: CGFloat = 18
        static let textSpacing: CGFloat = 28
        static let verticalPadding: CGFloat = 20
    }

    enum ProgressBar {
        static let height: CGFloat = 10
        static let strokeWidth: CGFloat = 1
        static let cornerRadius: CGFloat = 8
    }
}

private enum AccessibilityIDs {
    static func categoryLabel(for group: MuscleCategoryGroup) -> String {
        "id_label_\(group.id)"
    }
}

private struct ExerciseInfo {
    let total: Int
    let active: Int
    let isCompleted: Bool
    let progress: Double

    init(total: Int, active: Int) {
        self.total = total
        self.active = active
        self.isCompleted = (active == 0 && total > 0)
        self.progress = total > 0 ? Double(total - active) / Double(total) : 0.0
    }
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 18) {
                    headerView
                    Spacer().frame(height: 30)
                    categoryList
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, Constants.topPadding)
            }

            BottomActionBarView(
                viewModel: viewModel.bottomBarViewModel,
                onStart: {},
                onCompleteSet: {},
                onQuickDone: {},
                onCompleteAllQuickDone: {},
                onReset: {},
                onEditLess: {},
                onEditMore: {},
                onFinish: {},
                onAddExercise: {},
                onResetAllExercises: {
                    viewModel.resetAllExercises()
                }
            )
            .padding(.bottom, safeAreaInset)
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitle("")
        .onAppear {
            viewModel.updateExerciseCounts()
        }
    }

    private var headerView: some View {
        Text("Kategorien")
            .font(AppStyle.Font.cardHeadline)
            .foregroundColor(AppStyle.Color.white)
            .padding(.top, Constants.titleTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryList: some View {
        ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
            NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                CategoryTileView(group: group, viewModel: viewModel)
            }
        }
    }

    private var safeAreaInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

private struct CategoryTileView: View {
    let group: MuscleCategoryGroup
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel

    var body: some View {
        let exerciseInfo = createExerciseInfo()

        HStack(spacing: 0) {
            categoryInfoView(exerciseInfo: exerciseInfo)
            Spacer()
            progressSection(exerciseInfo: exerciseInfo)
        }
        .frame(maxWidth: .infinity)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }

    private func categoryInfoView(exerciseInfo: ExerciseInfo) -> some View {
        VStack(alignment: .leading, spacing: Constants.CategoryTile.textSpacing) {
            Text(group.displayName)
                .font(AppStyle.Font.categorySelectionNameFont)
                .foregroundColor(AppStyle.Color.white)

            Text("\(exerciseInfo.active) von \(exerciseInfo.total) Übungen")
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(Color(hex: "#8a8580"))
        }
        .padding(.vertical, Constants.CategoryTile.verticalPadding)
        .padding(.horizontal, Constants.CategoryTile.contentPadding)
    }

    private func progressSection(exerciseInfo: ExerciseInfo) -> some View {
        HStack(spacing: Constants.CategoryTile.itemSpacing) {
            VStack(alignment: .trailing, spacing: Constants.CategoryTile.verticalSpacing) {
                CustomChip(
                    text: exerciseInfo.isCompleted ? "Completed" : "Active",
                    isCompleted: exerciseInfo.isCompleted,
                    width: Constants.CategoryTile.barWidth,
                    verticalPadding: Constants.CategoryTile.chipVerticalPadding
                )
                .accessibilityIdentifier(AccessibilityIDs.categoryLabel(for: group))

                ProgressBar(progress: exerciseInfo.progress, totalWidth: Constants.CategoryTile.barWidth)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(AppStyle.Color.white)
                .imageScale(.medium)
        }
        .padding(.vertical, Constants.CategoryTile.verticalPadding)
        .padding(.horizontal, Constants.CategoryTile.contentPadding)
    }

    private func createExerciseInfo() -> ExerciseInfo {
        let count = viewModel.getExerciseCount(for: group) ?? (0, 0)
        return ExerciseInfo(total: count.total, active: count.active)
    }
}

private struct CustomChip: View {
    let text: String
    let isCompleted: Bool
    let width: CGFloat
    let verticalPadding: CGFloat

    var body: some View {
        Text(text)
            .font(AppStyle.Font.categorySelectionChipFont)
            .foregroundColor(.white)
            .frame(width: width)
            .padding(.vertical, verticalPadding)
            .background(chipBackground)
            .overlay(chipOverlay)
    }
    
    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: Constants.ProgressBar.cornerRadius)
            .fill(isCompleted ? AppStyle.Color.green : AppStyle.Color.exerciseCardBackground)
    }
    
    private var chipOverlay: some View {
        Group {
            if !isCompleted {
                RoundedRectangle(cornerRadius: Constants.ProgressBar.cornerRadius)
                    .stroke(Color(hex: "#8a8580"), lineWidth: 1)
            }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let totalWidth: CGFloat

    private let fillColor = AppStyle.Color.green
    private let trackColor = Color(hex: "#8a8580")

    var body: some View {
        ZStack(alignment: .leading) {
            trackView
            progressView
        }
        .frame(width: totalWidth, height: Constants.ProgressBar.height)
    }
    
    private var trackView: some View {
        Capsule()
            .strokeBorder(trackColor, lineWidth: Constants.ProgressBar.strokeWidth)
            .background(
                Capsule()
                    .fill(AppStyle.Color.exerciseCardBackground)
            )
            .frame(width: totalWidth, height: Constants.ProgressBar.height)
    }
    
    private var progressView: some View {
        Capsule()
            .fill(fillColor)
            .frame(
                width: CGFloat(progress.clamped(to: 0...1)) * totalWidth,
                height: Constants.ProgressBar.height
            )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
