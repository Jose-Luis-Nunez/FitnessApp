import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI

public struct InactiveCardView: View {
    public var viewModel: ExerciseCardViewModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel
    public let onReset: ((Exercise) -> Void)?
    public let isResetEnabled: Bool

    @State private var isShowingAnalytics = false
    @State private var isExpanded = false
    @State private var cachedSetProgress: [SetProgress] = []

    public init(
        viewModel: ExerciseCardViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        onReset: ((Exercise) -> Void)?,
        isResetEnabled: Bool
    ) {
        self.viewModel = viewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.onReset = onReset
        self.isResetEnabled = isResetEnabled
    }

    private func refreshSetProgress() {
        let latestEntry = analyticsViewModel
            .loadAnalytics(for: viewModel.exercise.id)
            .max(by: { $0.date < $1.date })
        cachedSetProgress = latestEntry?.setProgress ?? []
    }

    public var body: some View {
        CardBackground(useGlassEffect: true, addPadding: false) {
            VStack(spacing: 0) {
                headerRow

                if isExpanded {
                    Spacer().frame(height: 10)
                    setTilesRow.frame(height: 60)
                    Spacer().frame(height: 4)
                }
            }
            .padding(.horizontal, AppStyle.Padding.card)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                AppStyle.Color.greenGlow
                    .frame(width: AppStyle.Layout.completedBarWidth)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .shadow(color: AppStyle.Shadow.cardColor, radius: AppStyle.Shadow.cardRadius, x: 0, y: AppStyle.Shadow.cardY)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
        .onAppear { refreshSetProgress() }
        .onChange(of: analyticsViewModel.lastUpdatedExerciseId) { _, newId in
            if newId == viewModel.exercise.id { refreshSetProgress() }
        }
    }
}

// MARK: - Header

private extension InactiveCardView {

    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            checkmarkIcon
        }
    }

    var categoryIconView: some View {
        Image(viewModel.exercise.displayIconName)
            .resizable()
            .scaledToFill()
            .frame(width: AppStyle.Layout.categoryIconSize, height: AppStyle.Layout.categoryIconSize, alignment: viewModel.exercise.iconAlignment)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.exercise.name)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(ExerciseIDs.nameLabel)
                .onTapGesture {
                    if isEditable { onEdit(viewModel.exercise, .name) }
                }

            HStack(spacing: 4) {
                Text("Completed workout")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(.white.opacity(0.7))

                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.cardSmallLabel)
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var checkmarkIcon: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)

            Image(systemName: "checkmark")
                .font(AppStyle.Font.categoryTileCount)
                .foregroundColor(AppStyle.Color.exerciseCardBackground)
        }
        .onTapGesture { isExpanded.toggle() }
    }
}

// MARK: - Set Tiles

private extension InactiveCardView {

    var setTilesRow: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = cachedSetProgress.count > 3
            let scrollChevronWidth: CGFloat = 8
            let chevronArea: CGFloat = hasMoreThan3 ? scrollChevronWidth + spacing : 0
            let resetTotal: CGFloat = isResetEnabled ? ResetButton.Constants.size + spacing : 0
            let scrollAreaWidth = geo.size.width - resetTotal - chevronArea
            let tileWidth = (scrollAreaWidth - spacing * 2) / 3

            HStack(spacing: spacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(cachedSetProgress.indices, id: \.self) { index in
                            let item = cachedSetProgress[index]
                            SetTileView(setNumber: index + 1, weight: item.weight, reps: item.currentReps, hasWeight: viewModel.exercise.hasWeight)
                                .frame(width: tileWidth)
                        }
                    }
                }
                .frame(width: scrollAreaWidth)
                .onTapGesture { isShowingAnalytics = true }

                if hasMoreThan3 {
                    Image(systemName: "chevron.compact.right")
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: scrollChevronWidth)
                }

                if isResetEnabled {
                    ResetButton { onReset?(viewModel.exercise) }
                }
            }
        }
    }
}

// MARK: - Subviews

extension InactiveCardView {

    public struct ResetButton: View {
        public let onTap: () -> Void

        fileprivate enum Constants {
            static let size: CGFloat = 40
            static let iconSize: CGFloat = 32
        }

        public init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        public var body: some View {
            Button(action: onTap) {
                Image("repeat")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .frame(width: Constants.size, height: Constants.size)
                    .background(AppStyle.Color.exerciseCardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

}
