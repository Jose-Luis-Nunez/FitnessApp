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
    /// hides the play button + coaching controls so the row is narrower and
    /// all selectable cards line up at the same width.
    public let isSelectionMode: Bool
    public let isSelected: Bool

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var isLastRunExpanded = false
    @State private var weightPhases: [WeightPhase] = []
    @State private var lastRunSetProgress: [SetProgress] = []
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
        self.init(
            model: model,
            analyticsViewModel: analyticsViewModel,
            onEdit: onEdit,
            isEditable: isEditable,
            onStart: onStart,
            isInProgress: isInProgress,
            isSelectionMode: isSelectionMode,
            isSelected: isSelected,
            initiallyExpanded: false,
            initiallyLastRunExpanded: false
        )
    }

    init(
        model: ExerciseModel,
        analyticsViewModel: AnalyticsViewModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        onStart: ((Exercise) -> Void)?,
        isInProgress: Bool = false,
        isSelectionMode: Bool = false,
        isSelected: Bool = false,
        initiallyExpanded: Bool,
        initiallyLastRunExpanded: Bool
    ) {
        self.model = model
        self.analyticsViewModel = analyticsViewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.onStart = onStart
        self.isInProgress = isInProgress
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self._isExpanded = State(initialValue: initiallyExpanded)
        self._isLastRunExpanded = State(initialValue: initiallyLastRunExpanded)
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
        let latestEntry = analyticsViewModel
            .loadAnalytics(for: model.id)
            .max(by: { $0.date < $1.date })
        lastRunSetProgress = latestEntry?.setProgress ?? []
    }

    private let theme: CardTheme = .idle

    public var body: some View {
        CardShell(theme: theme, leading: {
            leadingContent
        }, trailing: {
            rightPanel
        }, titleContent: {
            titleSection
        }, expandedContent: {
            VStack(alignment: .leading, spacing: 8) {
                if isLastRunExpanded, !lastRunSetProgress.isEmpty {
                    lastRunTilesRow
                        .frame(height: AppStyle.Layout.idleLastRunDetailsHeight)
                        .padding(.horizontal, AppStyle.Padding.card)
                        .padding(.top, AppStyle.Layout.idleLastRunExpandedTopSpacing)
                }
                if isExpanded, !weightPhases.isEmpty {
                    expandedContent
                        .padding(.horizontal, AppStyle.Padding.idleExpandedContentHorizontal)
                }
            }
        }, contentBackground: {
            if isExpanded || isLastRunExpanded {
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
    enum IdleMetricLayout {
        static let separatorValueFooterAlignmentOffset: CGFloat = -14
    }

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
        if showsTrailingAction {
            playButton
        }
    }

    var showsTrailingAction: Bool {
        !isSelectionMode && onStart != nil && !model.isCompleted
    }

    var categoryIconView: some View {
        Image(iconColorScheme.iconName(for: model.categoryGroup.defaultIconName))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: AppStyle.Layout.idleActiveCardIconSize, height: AppStyle.Layout.idleActiveCardIconSize, alignment: model.categoryGroup.iconAlignment)
            .clipped()
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 0) {
                Text(model.name)
                    .font(AppStyle.Font.idleCardTitle)
                    .foregroundColor(AppStyle.Color.idleTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                    .onTapGesture {
                        if isEditable { onEdit(model.toDomain(), .name) }
                    }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            metricRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    var metricRow: some View {
        HStack(alignment: .metricLabel, spacing: 0) {
            weightColumn

            if !model.noSeats {
                Spacer(minLength: 0)
                verticalSeparator
                Spacer(minLength: 0)
                seatColumn
            }

            Spacer(minLength: 0)
            verticalSeparator
            Spacer(minLength: 0)
            progressColumn
            if showsTrailingAction {
                Spacer(minLength: 0)
                verticalSeparator
            }
        }
    }

    var verticalSeparator: some View {
        Rectangle()
            .fill(AppStyle.Color.idleDivider)
            .frame(width: AppStyle.Layout.separatorWidth, height: AppStyle.Layout.separatorHeight)
            .padding(.horizontal, AppStyle.Layout.idleMetricSeparatorHorizontalPadding)
            .alignmentGuide(.metricLabel) { d in
                d[VerticalAlignment.top] + IdleMetricLayout.separatorValueFooterAlignmentOffset
            }
    }

    var weightColumn: some View {
        MetricColumnView(
            label: model.hasWeight ? "Weight" : "Reps",
            onTap: isEditable ? { onEdit(model.toDomain(), .weight) } : nil
        ) {
            if model.hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(weightNumber)
                        .font(AppStyle.Font.idleWeightValue)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                    Text("kg")
                        .font(AppStyle.Font.idleWeightUnit)
                        .foregroundColor(AppStyle.Color.idleMetricValue)
                }
                .fixedSize()
            } else {
                // Bodyweight: show "sets x reps" on one line as "3x15" — no spaces
                // around the multiplier, and the "x" rendered smaller than the
                // numbers so the figures dominate.
                (
                    Text("\(model.sets)").font(AppStyle.Font.idleWeightValue)
                        + Text("x").font(AppStyle.Font.idleRepsSeparator)
                        + Text("\(model.reps)").font(AppStyle.Font.idleWeightValue)
                )
                .foregroundColor(AppStyle.Color.idleMetricValue)
                .lineLimit(1)
                .fixedSize()
            }
        }
    }

    var seatColumn: some View {
        MetricColumnView(
            label: "Seat",
            alignment: .center,
            onTap: isEditable ? { onEdit(model.toDomain(), .seat) } : nil
        ) {
            // Two slots — left/right seat position.
            // Only the first positions are shown on the card; any beyond
            // SeatSettings.idleCardVisibleLimit are stored but hidden here.
            // Empty slots render "-" (no value yet).
            let positions = SeatSettings(encoded: model.seatSetting).positions
            let left = positions.indices.contains(0) ? positions[0] : "-"
            let right = positions.indices.contains(1) ? positions[1] : "-"
            HStack(spacing: 8) {
                Text(left)
                Text(right)
            }
            .font(AppStyle.Font.idleSeatValue)
            .foregroundColor(AppStyle.Color.idleMetricValue)
            .lineLimit(1)
            .fixedSize()
            .frame(height: AppStyle.Layout.idleMetricContentRowHeight)
        } footer: {
            seatFooterIcon
        }
    }

    var seatFooterIcon: some View {
        Image("seat_arrow_small")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: AppStyle.Layout.seatIconSize, height: AppStyle.Layout.idleMetricGlyphHeight)
            .foregroundColor(AppStyle.Color.idleMetricValue)
            .frame(height: AppStyle.Layout.idleMetricFooterRowHeight)
    }

    var progressColumn: some View {
        VStack(alignment: .center, spacing: 4) {
            dataBand

            Image("analytics_icon_2")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: AppStyle.Layout.analyticsEntryIconWidth, height: AppStyle.Layout.idleMetricGlyphHeight)
                .foregroundColor(AppStyle.Color.idleMetricValue)
                .frame(height: AppStyle.Layout.idleMetricContentRowHeight)
                .accessibilityHidden(true)
                // Grow the interaction surface upward so the visual position and
                // the spacing to "Last run" remain unchanged.
                .overlay(alignment: .bottom) {
                    Button(action: {
                        analyticsSheetDate = AnalyticsSheetDate(date: Date())
                    }) {
                        Color.clear
                            .frame(
                                minWidth: AppStyle.Layout.minimumTapTargetSize,
                                minHeight: AppStyle.Layout.minimumTapTargetSize
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exercise analytics")
                    .accessibilityHint("Shows exercise analytics")
                }

            // "Last run" only appears once the exercise has a completed run;
            // before that the footer is omitted.
            if !isSelectionMode, !lastRunSetProgress.isEmpty {
                lastRunFooter
                    .padding(.top, AppStyle.Layout.idleLastRunFooterTopSpacing)
            }
        }
    }

    /// Non-interactive "Data" label above the analytics chart. Coaching now
    /// lives in the expanded "Last run" trailing rail.
    var dataBand: some View {
        Text("Data")
            .font(AppStyle.Font.metricLabel)
            .foregroundColor(AppStyle.Color.idleMetricLabel)
            .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }
            .fixedSize()
    }

    /// "Last run" entry: plain text + trailing chevron (no box). Taps expand the
    /// per-set breakdown.
    var lastRunFooter: some View {
        HStack(spacing: 6) {
            Text("Last run")
                .font(AppStyle.Font.metricLabel)
                .foregroundColor(AppStyle.Color.idleMetricValue)

            Image(systemName: "chevron.right")
                .font(AppStyle.Font.cardSmallLabel)
                .foregroundColor(AppStyle.Color.idleMetricLabel)
                .rotationEffect(.degrees(isLastRunExpanded ? 90 : 0))
        }
        .fixedSize()
        .accessibilityHidden(true)
        // Grow the interaction surface downward; together with the analytics
        // target's bottom alignment this prevents competing tap regions.
        .overlay(alignment: .top) {
            Button(action: toggleLastRunDetails) {
                Color.clear
                    .frame(
                        minWidth: AppStyle.Layout.minimumTapTargetSize,
                        minHeight: AppStyle.Layout.minimumTapTargetSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Last run details")
            .accessibilityValue(isLastRunExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isLastRunExpanded ? "Hides set details" : "Shows set details")
        }
    }

    func toggleLastRunDetails() {
        if isLastRunExpanded {
            isExpanded = false
        }
        isLastRunExpanded.toggle()
    }

    var coachingTipButton: some View {
        Button(action: { isExpanded.toggle() }) {
            coachingTipBadge
                .frame(
                    minWidth: AppStyle.Layout.minimumTapTargetSize,
                    minHeight: AppStyle.Layout.minimumTapTargetSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coaching tips")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Collapses coaching tips" : "Expands coaching tips")
    }

    /// Circular coaching glyph matching the completed card's reset-button size.
    var coachingTipBadge: some View {
        CardActionCircleButtonVisual(
            iconSize: ExerciseCardLayout.ResetButton.iconSize,
            discSize: ExerciseCardLayout.ResetButton.size,
            glowSize: ExerciseCardLayout.ResetButton.size
        ) {
            Image("tip_coaching_2")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    var playButton: some View {
        if let onStart = onStart, !model.isCompleted {
            Button(action: { onStart(model.toDomain()) }) {
                Group {
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
                .frame(
                    minWidth: AppStyle.Layout.minimumTapTargetSize,
                    minHeight: AppStyle.Layout.minimumTapTargetSize
                )
                .contentShape(Rectangle())
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

    /// Last-run per-set breakdown via the shared `SetTilesRow`. The idle card has
    /// no reset accessory. The idle layout reveals part of the next tile as its
    /// overflow affordance, so the coaching rail never needs a chevron.
    var lastRunTilesRow: some View {
        let showsCoaching = !weightPhases.isEmpty
        return SetTilesRow(
            setProgress: lastRunSetProgress,
            hasWeight: model.hasWeight,
            chevronColor: AppStyle.Color.idleMetricLabel.opacity(AppStyle.Opacity.separatorLine),
            reservedTrailingRailWidth: showsCoaching ? AppStyle.Layout.minimumTapTargetSize : 0,
            visibleTileCount: AppStyle.Layout.idleLastRunVisibleTileCount,
            showsOverflowChevron: false,
            onTap: { analyticsSheetDate = AnalyticsSheetDate(date: Date()) },
            trailingRailAccessory: {
                if showsCoaching {
                    coachingTipButton
                }
            }
        )
    }
}
