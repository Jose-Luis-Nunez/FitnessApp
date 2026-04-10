import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI

private extension VerticalAlignment {
    struct MetricLabelAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.top]
        }
    }

    static let metricLabel = VerticalAlignment(MetricLabelAlignment.self)
}

public struct IdleActiveCardView: View {
    @ObservedObject public var viewModel: ExerciseCardViewModel
    @ObservedObject public var analyticsViewModel: AnalyticsViewModel

    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public let onStart: ((Exercise) -> Void)?

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var weightPhases: [WeightPhase] = []
    @State private var lastTrainingDateFormatted: String?

    public init(
        viewModel: ExerciseCardViewModel,
        analyticsViewModel: AnalyticsViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        onStart: ((Exercise) -> Void)?
    ) {
        self.viewModel = viewModel
        self.analyticsViewModel = analyticsViewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.onStart = onStart
    }

    private struct AnalyticsSheetDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    private var formattedWeight: String {
        WeightFormatter.displayWeight(viewModel.exercise.weight)
    }

    private static let lastTrainingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        return f
    }()

    private func refreshPhaseData() {
        if viewModel.exercise.hasWeight {
            weightPhases = analyticsViewModel.weightPhases(for: viewModel.exercise.id)
        } else {
            weightPhases = analyticsViewModel.repsPhases(for: viewModel.exercise.id)
        }
        if let date = analyticsViewModel.lastTrainingDate(for: viewModel.exercise.id) {
            lastTrainingDateFormatted = Self.lastTrainingFormatter.string(from: date)
        } else {
            lastTrainingDateFormatted = nil
        }
    }

    public var body: some View {
        CardBackground(backgroundColor: AppStyle.Color.exerciseCardBackground, useGlassEffect: true, addPadding: false) {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, AppStyle.Padding.card)

                if isExpanded, !weightPhases.isEmpty {
                    expandedContent
                        .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
            .background {
                if isExpanded {
                    Color.white.opacity(AppStyle.Opacity.subtleBackground)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .sheet(item: $analyticsSheetDate) { sheetDate in
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel, initialDate: sheetDate.date)
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .shadow(color: AppStyle.Shadow.cardColor, radius: AppStyle.Shadow.cardRadius, x: 0, y: AppStyle.Shadow.cardY)
        .onAppear { refreshPhaseData() }
        .onReceive(
            analyticsViewModel.analyticsDidUpdate
                .filter { $0 == viewModel.exercise.id }
        ) { _ in refreshPhaseData() }
    }
}

// MARK: - Header

private extension IdleActiveCardView {

    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            Spacer(minLength: 4)
            playButton
        }
    }

    var categoryIconView: some View {
        Image(viewModel.exercise.category.defaultIconName)
            .resizable()
            .scaledToFill()
            .frame(width: AppStyle.Layout.categoryIconSize, height: AppStyle.Layout.categoryIconSize, alignment: viewModel.exercise.category.iconAlignment)
            .clipped()
            .foregroundColor(AppStyle.Color.white)
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
                .onTapGesture {
                    if isEditable { onEdit(viewModel.exercise, .name) }
                }

            metricRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricLabelFont: Font {
        AppStyle.Font.metricLabel
    }

    private var metricLabelColor: Color {
        .white.opacity(0.5)
    }

    var metricRow: some View {
        HStack(alignment: .metricLabel, spacing: 0) {
            weightColumn

            if !viewModel.exercise.noSeats {
                verticalSeparator
                seatColumn
            }

            verticalSeparator
            progressColumn

            Spacer(minLength: 0)
        }
    }

    var verticalSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: AppStyle.Layout.separatorHeight)
            .padding(.horizontal, AppStyle.Padding.card)
    }

    var weightColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.exercise.hasWeight ? "Weight" : "Reps")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if viewModel.exercise.hasWeight {
                Text(formattedWeight)
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            } else {
                Text("\(viewModel.exercise.sets) x \(viewModel.exercise.reps)")
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(viewModel.exercise, .weight) }
        }
    }

    var seatColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Seat")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
                Text(seat)
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                HStack(spacing: 2) {
                    Text("+")
                        .font(AppStyle.Font.detailBadge)
                        .foregroundColor(AppStyle.Color.greenGlow)

                    Image("chairSettings")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: AppStyle.Layout.seatIconSize, height: AppStyle.Layout.seatIconSize)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(viewModel.exercise, .seat) }
        }
    }

    var progressColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Progress")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            HStack(spacing: 16) {
                Button(action: {
                    analyticsSheetDate = AnalyticsSheetDate(date: Date())
                }) {
                    Image("analyticsEntry")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: AppStyle.Layout.analyticsEntryIconSize, height: AppStyle.Layout.analyticsEntryIconSize)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
                .buttonStyle(.plain)

                if !weightPhases.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(AppStyle.Font.tileLabel)
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .contentShape(Rectangle())
                        .onTapGesture { isExpanded.toggle() }
                }
            }
        }
    }

    @ViewBuilder
    var playButton: some View {
        if let onStart = onStart, !viewModel.exercise.isCompleted {
            Button(action: { onStart(viewModel.exercise) }) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.greenGlow)
                        .frame(width: AppStyle.Layout.playButtonSize, height: AppStyle.Layout.playButtonSize)

                    Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: AppStyle.Layout.playIconSize, height: AppStyle.Layout.playIconSize)
                        .foregroundColor(AppStyle.Color.exerciseCardBackground)
                }
            }
            .accessibilityIdentifier(MuscleCategoryIDs.startExercise)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Expanded Content

private extension IdleActiveCardView {

    var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dateString = lastTrainingDateFormatted {
                Text("Last training: \(dateString)")
                    .font(AppStyle.Font.dayChipNumber)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 6)
            }

            phaseTilesRow
        }
        .padding(.top, 4)
    }

    var phaseTilesRow: some View {
        HStack(spacing: 8) {
            ForEach(weightPhases) { phase in
                WeightPhaseTileView(phase: phase, hasWeight: viewModel.exercise.hasWeight)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        analyticsSheetDate = AnalyticsSheetDate(date: phase.startDate)
                    }
            }

            if weightPhases.count < 3 {
                ForEach(0..<(3 - weightPhases.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
}
