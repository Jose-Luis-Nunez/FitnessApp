import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI

public struct ActiveCardView: View {
    @ObservedObject public var viewModel: ExerciseCardViewModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    @ObservedObject public var analyticsViewModel: AnalyticsViewModel

    @State private var isShowingAnalytics = false

    public init(
        viewModel: ExerciseCardViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel
    ) {
        self.viewModel = viewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
    }

    private var formattedWeight: String {
        WeightFormatter.displayWeight(viewModel.exercise.weight)
    }

    private var iconOverflow: CGFloat { AppStyle.Padding.activeCardIconOverflow }

    public var body: some View {
        ZStack(alignment: .trailing) {
            CardBackground(useGlassEffect: true, addPadding: false) {
                cardContentView
                    .padding(.horizontal, AppStyle.Padding.card)
                    .padding(.vertical, 12)
            }

            exerciseIconSection
                .offset(y: -iconOverflow)
                .padding(.trailing, AppStyle.Padding.card)
        }
        .padding(.top, iconOverflow)
        .padding(.horizontal, AppStyle.Padding.card)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }

    @ViewBuilder
    private var cardContentView: some View {
        let contentView = HStack(alignment: .center, spacing: AppStyle.DeviceLayout.cardSpacing) {
            exerciseChipsSection
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: AppStyle.DeviceLayout.iconContainerWidth + AppStyle.DeviceLayout.analyticsToIconSpacing)
        }
        .frame(height: AppStyle.Layout.activeCardContentHeight)

        if AppStyle.DeviceLayout.isExtraLarge {
            contentView
                .frame(maxWidth: AppStyle.Layout.activeCardMaxWidth)
                .frame(maxWidth: .infinity)
        } else {
            contentView
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var exerciseChipsSection: some View {
        if viewModel.exercise.hasWeight {
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    setsChip
                    repsChip
                }
                weightChip
                analyticsButton
            }
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(AppStyle.Color.yellow)
                            .font(AppStyle.Font.iconSymbol)
                        Text("\(viewModel.exercise.sets)x")
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(AppStyle.Color.white)
                    }
                }

                MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppStyle.Color.green)
                            .font(AppStyle.Font.iconSymbol)
                        Text("\(viewModel.exercise.reps)")
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(AppStyle.Color.white)
                    }
                }

                analyticsButton
            }
        }
    }

    private var setsChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.chipWidthVertical, height: AppStyle.Layout.chipHeight) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(AppStyle.Color.yellow)
                    .font(AppStyle.Font.tileLabel)
                Text("\(viewModel.exercise.sets)x")
                    .font(AppStyle.Font.regularChip)
                    .foregroundColor(AppStyle.Color.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var repsChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.chipWidthVertical, height: AppStyle.Layout.chipHeight) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(AppStyle.Color.green)
                    .font(AppStyle.Font.tileLabel)
                Text("\(viewModel.exercise.reps)")
                    .font(AppStyle.Font.regularChip)
                    .foregroundColor(AppStyle.Color.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var weightChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
            Text(formattedWeight)
                .font(AppStyle.Font.regularChip)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
    }

    private var analyticsButton: some View {
        Button(action: {
            isShowingAnalytics = true
        }) {
            MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                Image("analyticsEntry")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: AppStyle.Layout.analyticsImageSize, height: AppStyle.Layout.analyticsImageSize)
                    .foregroundStyle(AppStyle.Color.trainingAccent)
            }
        }
        .buttonStyle(.plain)
    }

    private var exerciseIconSection: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.greenBlack)
                    .frame(width: AppStyle.DeviceLayout.exerciseIconSize * 0.9, height: AppStyle.DeviceLayout.exerciseIconSize * 0.9)
                    .blur(radius: AppStyle.Blur.iconGlow)
                    .opacity(AppStyle.Opacity.overlayBackdrop)

                Image(viewModel.exercise.displayIconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AppStyle.DeviceLayout.exerciseIconSize, height: AppStyle.DeviceLayout.exerciseIconSize, alignment: viewModel.exercise.iconAlignment)
                    .clipped()
            }
        }
        .frame(width: AppStyle.DeviceLayout.iconContainerWidth)
        .frame(maxHeight: .infinity)
    }
}
