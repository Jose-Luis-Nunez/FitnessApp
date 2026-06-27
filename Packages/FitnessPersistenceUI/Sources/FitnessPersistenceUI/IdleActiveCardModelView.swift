import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Idle/Active card variant rendered against a live `@Bindable ExerciseModel`.
///
/// The data source is the SwiftData `@Model` instance — all edits propagate
/// automatically without snapshot sync (ADR-0001). Still keeps the
/// `analyticsViewModel.changeCount` polling pattern; that will be resolved in a later
/// step in favor of direct `@Observable` tracking.
///
/// SPI marker: see `ExerciseCardModelView`.
@_spi(PersistenceUI)
public struct IdleActiveCardModelView: View {
    @Bindable public var model: ExerciseModel
    public var analyticsViewModel: AnalyticsViewModel

    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public let onStart: ((Exercise) -> Void)?
    public let isInProgress: Bool
    /// Selection (deactivate/activate) mode: shows a leading radio button and
    /// hides the play button + the coaching-tip ("Glühbirne") box so the row is
    /// narrower and all selectable cards line up at the same width.
    public let isSelectionMode: Bool
    public let isSelected: Bool

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var weightPhases: [WeightPhase] = []
    @State private var lastTrainingDateFormatted: String?
    @AppStorage(DefaultIconColorScheme.storageKey) private var iconColorScheme: DefaultIconColorScheme = .green

    public init(
        model: ExerciseModel,
        analyticsViewModel: AnalyticsViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        onStart: ((Exercise) -> Void)?,
        isInProgress: Bool = false,
        isSelectionMode: Bool = false,
        isSelected: Bool = false
    ) {
        self.model = model
        self.analyticsViewModel = analyticsViewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.onStart = onStart
        self.isInProgress = isInProgress
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
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
            leadingContent
        }, secondTrailing: {
            if !isSelectionMode {
                tipColumn
            }
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
        .frame(minWidth: AppStyle.Layout.idleCardContentMinWidth, maxWidth: .infinity)
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
    var leadingContent: some View {
        if isSelectionMode {
            HStack(spacing: AppStyle.Padding.card) {
                selectionRadio
                categoryIconView
            }
        } else {
            categoryIconView
        }
    }

    var selectionRadio: some View {
        ZStack {
            Circle()
                .strokeBorder(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel), lineWidth: AppStyle.Layout.selectionRadioStroke)
                .frame(width: AppStyle.Layout.selectionRadioSize, height: AppStyle.Layout.selectionRadioSize)
            if isSelected {
                Circle()
                    .fill(AppStyle.Color.greenGlow)
                    .frame(width: AppStyle.Layout.selectionRadioDot, height: AppStyle.Layout.selectionRadioDot)
            }
        }
        .frame(width: AppStyle.Layout.selectionRadioFrame, height: AppStyle.Layout.selectionRadioFrame)
        .accessibilityIdentifier(ExerciseCardIDs.selectionToggle(model.id))
    }

    @ViewBuilder
    var rightPanel: some View {
        if !isSelectionMode, onStart != nil, !model.isCompleted {
            playButton
        }
    }

    var categoryIconView: some View {
        Image(iconColorScheme.iconName(for: model.categoryGroup.defaultIconName))
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
            let seats = SeatSettings(encoded: model.seatSetting)
            if !seats.positions.isEmpty {
                // Only the first positions are shown on the card; any beyond
                // SeatSettings.idleCardVisibleLimit are stored but hidden here.
                Text(seats.display(limit: SeatSettings.idleCardVisibleLimit))
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
            Image("tip_coaching_2")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: AppStyle.Layout.tipIconSize, height: AppStyle.Layout.tipIconSize)
                .foregroundColor(AppStyle.Color.idleMetricValue)
                .frame(width: AppStyle.Layout.idlePlayButtonSize, height: AppStyle.Layout.idlePlayButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
