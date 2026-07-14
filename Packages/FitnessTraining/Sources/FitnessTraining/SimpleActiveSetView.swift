import SwiftUI
import FitnessCore
import FitnessUI

public struct SimpleActiveSetView: View {
    public let exercise: Exercise
    @Binding public var setProgress: [SetProgress]
    public var viewModel: ActiveSetViewModel

    public init(exercise: Exercise, setProgress: Binding<[SetProgress]>, viewModel: ActiveSetViewModel) {
        self.exercise = exercise
        _setProgress = setProgress
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(setProgress.enumerated()), id: \.element.id) { index, progress in
                SetRowView(
                    index: index,
                    progress: progress,
                    exercise: exercise,
                    viewModel: viewModel,
                    isQuickDoneMode: viewModel.quickDoneModeActive
                )
            }
        }
        .padding(.horizontal, AppStyle.DeviceLayout.cardPadding)
        .padding(.vertical, 12)
        .background {
            Color.clear
                .appDarkSurface(
                    in: .rect(cornerRadius: AppStyle.CornerRadius.card)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
        .onChange(of: viewModel.pendingSetIndex) { index in
            if let index = index {
                viewModel.processQuickDone(at: index)
                viewModel.pendingSetIndex = nil
            }
        }
    }
}

// MARK: - SetRowChip Modifier

public struct SetRowChipStyle: ViewModifier {
    public let minWidth: CGFloat

    public init(minWidth: CGFloat) {
        self.minWidth = minWidth
    }

    public func body(content: Content) -> some View {
        content
            .font(AppStyle.Font.tileLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(minWidth: minWidth, minHeight: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppStyle.Color.metricChipBackground)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 1)
            )
    }
}

public extension View {
    func setRowChipStyle(minWidth: CGFloat) -> some View {
        modifier(SetRowChipStyle(minWidth: minWidth))
    }
}

// MARK: - Unified Set Row

private struct SetRowView: View {
    let index: Int
    let progress: SetProgress
    let exercise: Exercise
    var viewModel: ActiveSetViewModel
    let isQuickDoneMode: Bool

    private var isHighlighted: Bool {
        index == viewModel.activeSetIndex || (progress.status != .notStarted && progress.status != .inProgress)
    }

    private var isPending: Bool {
        progress.status == .notStarted || progress.status == .inProgress
    }

    var body: some View {
        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            setNumberBadge

            if exercise.hasWeight {
                weightChip
            }

            repsChip

            repsLabel

            if isQuickDoneMode && isPending {
                doneButton
            }
        }
        .padding(.horizontal, AppStyle.DeviceLayout.cardPadding)
    }

    private var setNumberBadge: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.backgroundColor)
                .frame(width: AppStyle.Layout.setRowBadgeSize, height: AppStyle.Layout.setRowBadgeSize)

            if !isQuickDoneMode && index == viewModel.activeSetIndex && !viewModel.quickDoneAllCompleted {
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
                    .frame(width: AppStyle.Layout.setRowBadgeSize, height: AppStyle.Layout.setRowBadgeSize)
            }

            Text("\(index + 1)")
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white)
        }
        .opacity(isHighlighted ? 1.0 : 0.3)
    }

    private var weightChip: some View {
        Button(WeightFormatter.displayWeight(progress.weight)) {
            if !isPending {
                viewModel.startEditingSet(index: index, mode: .edit)
            }
        }
        .setRowChipStyle(minWidth: AppStyle.DeviceLayout.setRowWeightMinWidth)
        .buttonStyle(PlainButtonStyle())
        .opacity(isHighlighted ? 1.0 : 0.3)
    }

    private var repsChip: some View {
        Button(!isPending ? "\(progress.currentReps)" : "") {
            viewModel.startEditingSet(index: index, mode: .edit)
        }
        .setRowChipStyle(minWidth: exercise.hasWeight ? 35 : AppStyle.DeviceLayout.setRowRepsMinWidth)
        .buttonStyle(PlainButtonStyle())
        .opacity(isHighlighted ? 1.0 : 0.3)
        .accessibilityIdentifier(TrainingIDs.repsField(set: index))
    }

    private var repsLabel: some View {
        Text("of \(exercise.reps)")
            .font(AppStyle.Font.detailExercise)
            .foregroundColor(AppStyle.Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: true, vertical: false)
            .opacity(isHighlighted ? 1.0 : 0.3)
    }

    private var doneButton: some View {
        Button("Done") {
            viewModel.pendingSetIndex = index
        }
        .font(AppStyle.Font.regularChip)
        .foregroundColor(AppStyle.Color.white)
        .frame(width: AppStyle.Layout.doneButtonWidth, height: AppStyle.Layout.doneButtonHeight)
        .background(AppStyle.Color.primaryButton)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
        .buttonStyle(PlainButtonStyle())
        .disabled(progress.status == .completedDone || viewModel.isLastSetCompleted)
        .accessibilityIdentifier(TrainingIDs.quickDoneSetButton(index: index))
    }
}
