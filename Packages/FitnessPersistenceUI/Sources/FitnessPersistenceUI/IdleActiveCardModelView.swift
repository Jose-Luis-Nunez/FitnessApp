import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

private extension VerticalAlignment {
    struct MetricLabelAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.top]
        }
    }

    static let metricLabel = VerticalAlignment(MetricLabelAlignment.self)
}

/// Live-bound spiegel von `IdleActiveCardView`. Layout 1:1 übernommen, Datenquelle
/// auf `@Bindable ExerciseModel`.
///
/// Behält das `analyticsViewModel.changeCount`-Polling-Pattern der alten Card —
/// das wird in T8 zugunsten direktem `@Observable`-Tracking aufgelöst (siehe
/// ADR-0001, "Aufgeschoben für T8").
///
/// SPI-Marker: siehe `ExerciseCardModelView`.
@_spi(PersistenceUI)
public struct IdleActiveCardModelView: View {
    @Bindable public var model: ExerciseModel
    public var analyticsViewModel: AnalyticsViewModel

    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public let onStart: ((Exercise) -> Void)?
    public let isInProgress: Bool

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var weightPhases: [WeightPhase] = []
    @State private var lastTrainingDateFormatted: String?

    public init(
        model: ExerciseModel,
        analyticsViewModel: AnalyticsViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        onStart: ((Exercise) -> Void)?,
        isInProgress: Bool = false
    ) {
        self.model = model
        self.analyticsViewModel = analyticsViewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.onStart = onStart
        self.isInProgress = isInProgress
    }

    private struct AnalyticsSheetDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    private var formattedWeight: String {
        WeightFormatter.displayWeight(model.weight)
    }

    private static let lastTrainingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        return f
    }()

    private func refreshPhaseData() {
        if model.hasWeight {
            weightPhases = analyticsViewModel.weightPhases(for: model.id)
        } else {
            weightPhases = analyticsViewModel.repsPhases(for: model.id)
        }
        if let date = analyticsViewModel.lastTrainingDate(for: model.id) {
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
                AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel, initialDate: sheetDate.date)
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .shadow(color: AppStyle.Shadow.cardColor, radius: AppStyle.Shadow.cardRadius, x: 0, y: AppStyle.Shadow.cardY)
        .onAppear { refreshPhaseData() }
        .onChange(of: analyticsViewModel.changeCount) { _, _ in
            refreshPhaseData()
        }
    }
}

// MARK: - Header

private extension IdleActiveCardModelView {

    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            Spacer(minLength: 4)
            playButton
        }
    }

    var categoryIconView: some View {
        Image(model.categoryGroup.defaultIconName)
            .resizable()
            .scaledToFill()
            .frame(width: AppStyle.Layout.categoryIconSize, height: AppStyle.Layout.categoryIconSize, alignment: model.categoryGroup.iconAlignment)
            .clipped()
            .foregroundColor(AppStyle.Color.white)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.name)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    if isEditable { onEdit(model.toDomain(), .name) }
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

            if !model.noSeats {
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
            Text(model.hasWeight ? "Weight" : "Reps")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if model.hasWeight {
                Text(formattedWeight)
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            } else {
                Text("\(model.sets) x \(model.reps)")
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(model.toDomain(), .weight) }
        }
    }

    var seatColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Seat")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if let seat = model.seatSetting, !seat.isEmpty {
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
            if isEditable { onEdit(model.toDomain(), .seat) }
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
        if let onStart = onStart, !model.isCompleted {
            Button(action: { onStart(model.toDomain()) }) {
                if isInProgress {
                    Image("trainin_progress")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(AppStyle.Color.yellow)
                        .frame(width: AppStyle.Layout.checkmarkSize * 2, height: AppStyle.Layout.checkmarkSize * 2)
                        .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)
                        .clipped()
                } else {
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
            }
            .accessibilityIdentifier(MuscleCategoryIDs.startExercise)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Expanded Content

private extension IdleActiveCardModelView {

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
                WeightPhaseTileView(phase: phase, hasWeight: model.hasWeight)
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
