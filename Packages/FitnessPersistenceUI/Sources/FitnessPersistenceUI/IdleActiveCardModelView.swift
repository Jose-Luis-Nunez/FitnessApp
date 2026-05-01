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

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, AppStyle.Padding.card)

            if isExpanded, !weightPhases.isEmpty {
                expandedContent
                    .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if isExpanded {
                AppStyle.Color.idleCardBackground.opacity(0.6)
            }
        }
        .background(idleCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [AppStyle.Color.idleCardInnerGlow, .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppStyle.Color.idleCardBorderLight, AppStyle.Color.idleCardBorderDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: AppStyle.Layout.idleCardBorderWidth
                )
        )
        .sheet(item: $analyticsSheetDate) { sheetDate in
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel, initialDate: sheetDate.date)
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

    var idleCardSurface: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                AppStyle.Color.idleCardSoft,
                AppStyle.Color.idleCardBackground,
                AppStyle.Color.idleCardDark,
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            Spacer(minLength: 4)
            rightPanel
        }
    }

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
                .font(AppStyle.Font.cardHeadline)
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

    private var metricLabelFont: Font {
        AppStyle.Font.metricLabel
    }

    private var metricLabelColor: Color {
        AppStyle.Color.idleMetricLabel
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
            .fill(Color.white.opacity(0.3))
            .frame(width: AppStyle.Layout.separatorWidth, height: AppStyle.Layout.separatorHeight)
            .padding(.horizontal, AppStyle.Padding.card)
            .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.top] + 4 }
    }

    var weightColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.hasWeight ? "Weight" : "Reps")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if model.hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(weightNumber)
                        .font(AppStyle.Font.detailBadge)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                    Text("kg")
                        .font(AppStyle.Font.detailBadge)
                        .foregroundColor(AppStyle.Color.idleMetricLabel)
                }
                .fixedSize()
            } else {
                Text("\(model.sets) x \(model.reps)")
                    .font(AppStyle.Font.detailBadge)
                    .foregroundColor(AppStyle.Color.idleMetricValue)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(model.toDomain(), .weight) }
        }
    }

    var seatColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Seat")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

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
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(model.toDomain(), .seat) }
        }
    }

    var progressColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Data")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
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
