import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Idle/Active card variant rendered against a live `@Bindable ExerciseModel`.
///
/// Datenquelle ist die SwiftData-`@Model`-Instanz — alle Edits propagieren
/// automatisch ohne Snapshot-Sync (ADR-0001). Behält noch das
/// `analyticsViewModel.changeCount`-Polling-Pattern; das wird in einem späteren
/// Schritt zugunsten direkten `@Observable`-Trackings aufgelöst.
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

    /// Numeric portion of the displayed weight, without the unit suffix.
    /// The unit (`kg`) is rendered as a separate `Text` so it can carry the
    /// muted label color while the number reads in the value-tier mint.
    private var weightNumber: String {
        WeightFormatter.format(model.weight)
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

    private let theme: CardTheme = .idle

    public var body: some View {
        CardShell(theme: theme, leading: {
            categoryIconView
        }, trailing: {
            rightPanel
        }, titleContent: {
            titleSection
        }, expandedContent: {
            if isExpanded, !weightPhases.isEmpty {
                expandedContent
                    .padding(.horizontal, 8)
            }
        }, contentBackground: {
            if isExpanded {
                AppStyle.Color.idleCardBackground.opacity(AppStyle.Opacity.idleExpandedOverlay)
            }
        })
        .sheet(item: $analyticsSheetDate) { sheetDate in
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel, initialDate: sheetDate.date)
        }
        .onAppear { refreshPhaseData() }
        .onChange(of: analyticsViewModel.changeCount) { _, _ in
            refreshPhaseData()
        }
    }
}

// MARK: - Header

private extension IdleActiveCardModelView {

    @ViewBuilder
    var rightPanel: some View {
        if onStart != nil, !model.isCompleted {
            playButton
        }
    }

    var categoryIconView: some View {
        Image(model.categoryGroup.defaultIconName)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: AppStyle.Layout.idleCategoryIconSize, height: AppStyle.Layout.idleCategoryIconSize, alignment: model.categoryGroup.iconAlignment)
            .clipped()
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.name)
                .font(AppStyle.Font.idleCardTitle)
                .foregroundColor(AppStyle.Color.idleTitle)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    if isEditable { onEdit(model.toDomain(), .name) }
                }

            metricRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            verticalSeparator
            tipColumn

            Spacer(minLength: 0)
        }
    }

    var verticalSeparator: some View {
        Rectangle()
            .fill(AppStyle.Color.idleDivider)
            .frame(width: AppStyle.Layout.separatorWidth, height: AppStyle.Layout.separatorHeight)
            .padding(.horizontal, AppStyle.Padding.card)
            .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.top] + 4 }
    }

    var weightColumn: some View {
        MetricColumnView(
            label: model.hasWeight ? "Weight" : "Reps",
            onTap: isEditable ? { onEdit(model.toDomain(), .weight) } : nil
        ) {
            if model.hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(weightNumber)
                        .font(AppStyle.Font.detailBadge)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                    Text("kg")
                        .font(AppStyle.Font.detailBadge)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                }
                .fixedSize()
            } else {
                Text("\(model.sets) x \(model.reps)")
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.idleMetricValue)
                    .fixedSize()
            }
        }
    }

    var seatColumn: some View {
        MetricColumnView(
            label: "Seat",
            onTap: isEditable ? { onEdit(model.toDomain(), .seat) } : nil
        ) {
            if let seat = model.seatSetting, !seat.isEmpty {
                Text(seat)
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.idleMetricValue)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Image("seat_arrow_small")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: AppStyle.Layout.seatIconSize, height: AppStyle.Layout.seatIconSize / 2)
                    .foregroundColor(AppStyle.Color.idleMetricValue)
                    .padding(.top, 2)
            }
        }
    }

    var progressColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Data")
                .font(AppStyle.Font.metricLabel)
                .foregroundColor(AppStyle.Color.idleMetricLabel)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            Button(action: {
                analyticsSheetDate = AnalyticsSheetDate(date: Date())
            }) {
                Image("analyticsEntry")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: AppStyle.Layout.analyticsEntryIconSize, height: AppStyle.Layout.analyticsEntryIconSize)
                    .foregroundColor(AppStyle.Color.idleMetricValue)
            }
            .buttonStyle(.plain)
        }
    }

    var tipColumn: some View {
        Button(action: { isExpanded.toggle() }) {
            RoundedRectangle(cornerRadius: AppStyle.Layout.tipBoxCornerRadius, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.Layout.tipBoxCornerRadius, style: .continuous)
                        .strokeBorder(AppStyle.Color.idlePlayRingBase, lineWidth: AppStyle.Layout.idlePlayRingWidth)
                )
                .overlay(
                    Image("tip_coaching")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: AppStyle.Layout.tipIconSize, height: AppStyle.Layout.tipIconSize)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                )
                .frame(width: AppStyle.Layout.tipBoxSize, height: AppStyle.Layout.tipBoxSize)
        }
        .buttonStyle(.plain)
        .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.top] + 4 }
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
                        .frame(width: AppStyle.Layout.idlePlayButtonSize, height: AppStyle.Layout.idlePlayButtonSize)
                } else {
                    IdlePlayButton()
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
                    .foregroundColor(.white.opacity(AppStyle.Opacity.secondaryLabel))
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
