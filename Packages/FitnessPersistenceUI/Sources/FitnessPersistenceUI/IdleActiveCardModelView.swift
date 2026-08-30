import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessResources
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

struct LastRunCardPresentationState {
    private(set) var hasHistory = false
    private(set) var setProgress: [SetProgress] = []
    private(set) var date: Date?

    mutating func updateAvailability(_ hasHistory: Bool) {
        self.hasHistory = hasHistory
        if !hasHistory {
            setProgress = []
            date = nil
        }
    }

    mutating func applyAvailability(_ outcome: AnalyticsHistoryAvailabilityOutcome) {
        guard case let .loaded(hasHistory) = outcome else { return }
        updateAvailability(hasHistory)
    }

    /// Applies only completed reads. A failed read deliberately preserves the
    /// current affordance and payload so the next user tap can retry.
    mutating func apply(
        _ outcome: LatestAnalyticsEntryLoadOutcome
    ) -> Bool {
        switch outcome {
        case .failed:
            return false
        case .loaded(nil):
            updateAvailability(false)
            return false
        case let .loaded(entry?):
            hasHistory = true
            setProgress = entry.setProgress
            date = entry.date
            return !setProgress.isEmpty
        }
    }
}

/// Zoomed muscle artwork for the frameless exercise rows. The focused crop
/// stays intact while a short bottom fade softens its hard frame edge.
struct ExerciseCardArtworkView: View {
    let image: Image
    let size: CGFloat
    let alignment: Alignment

    var body: some View {
        image
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size, alignment: alignment)
            .clipped()
            .mask {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.90),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}

/// Idle/Active card variant rendered against a live `@Bindable ExerciseModel`.
///
/// The data source is the SwiftData `@Model` instance — all edits propagate
/// automatically without snapshot sync (ADR-0001). Analytics refreshes carry
/// an Exercise id, so unrelated cards keep their staged analytics state.
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
    let imageProvider: (String) -> Image

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var isLastRunExpanded = false
    @State private var lastRunPresentation = LastRunCardPresentationState()
    @State private var weightPhases: [WeightPhase] = []
    @State private var analyticsRevision: ExerciseAnalyticsCacheRevision
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

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
            initiallyLastRunExpanded: false,
            imageProvider: { Image($0) }
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
        imageProvider: @escaping (String) -> Image
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
            initiallyLastRunExpanded: false,
            imageProvider: imageProvider
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
        initiallyLastRunExpanded: Bool,
        imageProvider: @escaping (String) -> Image = { Image($0) }
    ) {
        self.model = model
        self.analyticsViewModel = analyticsViewModel
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.onStart = onStart
        self.isInProgress = isInProgress
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.imageProvider = imageProvider
        self._isExpanded = State(initialValue: initiallyExpanded)
        self._isLastRunExpanded = State(initialValue: initiallyLastRunExpanded)
        self._analyticsRevision = State(
            initialValue: analyticsViewModel.revisionSource(for: model.id)
        )
    }

    private struct AnalyticsSheetDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    /// Numeric portion of the displayed weight, without the unit suffix.
    /// The unit (`kg`) is rendered as a separate `Text` so it can carry the
    /// muted label color while the number remains white.
    private var weightNumber: String {
        WeightFormatter.format(model.weight, locale: locale)
    }

    private func refreshAvailability() {
        lastRunPresentation.applyAvailability(
            analyticsViewModel.loadAnalyticsHistoryAvailability(for: model.id)
        )
    }

    private func loadLastRun() -> Bool {
        lastRunPresentation.apply(analyticsViewModel.loadLatestEntry(for: model.id))
    }

    private func handleAppear() {
        refreshAvailability()
        if isLastRunExpanded {
            _ = loadLastRun()
        }
        if isExpanded {
            weightPhases = analyticsViewModel.loadCardPhases(
                for: model.id,
                hasWeight: model.hasWeight
            )
        }
    }

    private func refreshVisibleAnalytics() {
        refreshAvailability()
        if isLastRunExpanded {
            _ = loadLastRun()
        }
        if isExpanded {
            weightPhases = analyticsViewModel.loadCardPhases(
                for: model.id,
                hasWeight: model.hasWeight
            )
        }
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
                if isLastRunExpanded, !lastRunPresentation.setProgress.isEmpty {
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
        })
        .frame(maxWidth: .infinity)
        .sheet(item: $analyticsSheetDate) { sheetDate in
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel, initialDate: sheetDate.date)
        }
        .onAppear { handleAppear() }
        .onChange(of: analyticsRevision.value) {
            refreshVisibleAnalytics()
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
                    .fill(appColorTheme.accent.glow)
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
        ExerciseCardArtworkView(
            image: imageProvider(appColorTheme.scheme.iconName(for: model.categoryGroup.defaultIconName)),
            size: AppStyle.Layout.idleActiveCardIconSize,
            alignment: model.categoryGroup.iconAlignment
        )
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
                    .accessibilityIdentifier(ExerciseIDs.nameLabel)
                    .onTapGesture {
                        if isEditable { onEdit(model.toDomain(), .full) }
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
        HStack(alignment: .top, spacing: 0) {
            weightColumn

            if !model.noSeats {
                Spacer(minLength: 0)
                seatColumn
            }

            Spacer(minLength: 0)
            progressColumn
            if showsTrailingAction {
                Spacer(minLength: 0)
            }
        }
    }

    var weightColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            weightValue

            // The footer owns its tap target so expanding the last run cannot
            // also trigger the weight editor above it.
            if !isSelectionMode, lastRunPresentation.hasHistory {
                lastRunFooter
            }
        }
    }

    @ViewBuilder
    var weightValue: some View {
        let content = Group {
            if model.hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: weightNumber)
                        .font(AppStyle.Font.idleWeightValue)
                        .foregroundColor(AppStyle.Color.white)
                    Text(verbatim: "kg")
                        .font(AppStyle.Font.cardMetricUnit)
                        .foregroundColor(appColorTheme.accent.idleMetricValue)
                }
                .fixedSize()
                .frame(height: AppStyle.Layout.idleMetricContentRowHeight)
            } else {
                // Bodyweight: show "sets x reps" on one line as "3x15" — no spaces
                // around the multiplier, and the "x" rendered smaller than the
                // numbers so the figures dominate.
                (
                    Text(verbatim: "\(model.sets)").font(AppStyle.Font.idleWeightValue)
                        + Text(verbatim: "x").font(AppStyle.Font.idleRepsSeparator)
                        + Text(verbatim: "\(model.reps)").font(AppStyle.Font.idleWeightValue)
                )
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .fixedSize()
                .frame(height: AppStyle.Layout.idleMetricContentRowHeight)
            }
        }
        let accessibleContent = content
            .frame(
                minWidth: AppStyle.Layout.minimumTapTargetSize,
                alignment: .leading
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.hasWeight ? AppText.profileWeight : AppText.exerciseReps)
            .accessibilityValue(
                model.hasWeight ? "\(weightNumber) kg" : "\(model.sets) x \(model.reps)"
            )

        if isEditable {
            Button(action: { onEdit(model.toDomain(), .weight) }) {
                accessibleContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            accessibleContent
        }
    }

    @ViewBuilder
    var seatColumn: some View {
        // Show up to two stored positions. A single position stands on its own;
        // the separator is rendered only when a second value exists.
        let positions = SeatSettings(encoded: model.seatSetting).cardPositions
        let accessibilityValue = positions.isEmpty ? "-" : positions.joined(separator: ", ")
        let content = HStack(spacing: 8) {
            Text(verbatim: positions.first ?? "-")
                .foregroundColor(AppStyle.Color.white)

            if positions.count == SeatSettings.cardDisplayLimit {
                Text(verbatim: "•")
                    .font(AppStyle.Font.idleSeatSeparator)
                    .foregroundColor(AppStyle.Color.white)
                Text(verbatim: positions[1])
                    .foregroundColor(AppStyle.Color.white)
            }

            seatAdjustmentIcon
        }
            .font(AppStyle.Font.idleSeatValue)
            .lineLimit(1)
            .fixedSize()
            .frame(
                minWidth: AppStyle.Layout.minimumTapTargetSize,
                minHeight: AppStyle.Layout.idleMetricContentRowHeight,
                alignment: .leading
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppText.exerciseSeat)
            .accessibilityValue(accessibilityValue)

        if isEditable {
            Button(action: { onEdit(model.toDomain(), .seat) }) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    var seatAdjustmentIcon: some View {
        imageProvider("seat_arrow_medium")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: AppStyle.Layout.seatIconSize, height: AppStyle.Layout.seatIconHeight)
            .foregroundColor(appColorTheme.accent.idleMetricValue)
    }

    var progressColumn: some View {
        imageProvider("analytics_icon_2")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: AppStyle.Layout.analyticsEntryIconWidth, height: AppStyle.Layout.idleMetricGlyphHeight)
            .foregroundColor(appColorTheme.accent.idleMetricValue)
            .frame(height: AppStyle.Layout.idleMetricContentRowHeight)
            .accessibilityHidden(true)
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
                .accessibilityLabel(AppText.analyticsExerciseAccessibility)
                .accessibilityHint(AppText.accessibilityShowsExerciseAnalytics)
                .accessibilityIdentifier(ExerciseCardIDs.analytics(model.id))
            }
    }

    /// "Last run" entry: plain text + trailing chevron (no box). Taps expand the
    /// per-set breakdown.
    var lastRunFooter: some View {
        HStack(spacing: 6) {
            Text(AppText.trainingLastRun)
                .font(AppStyle.Font.metricLabel)
                .foregroundColor(AppStyle.Color.idleMetricUnit)

            Image(systemName: "chevron.right")
                .font(AppStyle.Font.cardSmallLabel)
                .foregroundColor(AppStyle.Color.idleMetricUnit)
                .rotationEffect(.degrees(isLastRunExpanded ? 90 : 0))
        }
        .fixedSize()
        .frame(height: AppStyle.Layout.idleMetricFooterRowHeight)
        .accessibilityHidden(true)
        // Grow the interaction surface downward without overlapping the
        // independent Weight/Reps edit target above it.
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
            .accessibilityLabel(AppText.accessibilityLastRunDetails)
            .accessibilityValue(isLastRunExpanded ? AppText.commonExpanded : AppText.commonCollapsed)
            .accessibilityHint(isLastRunExpanded ? AppText.accessibilityHidesSetDetails : AppText.accessibilityShowsSetDetails)
        }
    }

    func toggleLastRunDetails() {
        if isLastRunExpanded {
            isExpanded = false
            isLastRunExpanded = false
            return
        }
        guard loadLastRun() else { return }
        isLastRunExpanded = true
    }

    var coachingTipButton: some View {
        Button(action: toggleCoachingTips) {
            coachingTipBadge
                .frame(
                    minWidth: AppStyle.Layout.minimumTapTargetSize,
                    minHeight: AppStyle.Layout.minimumTapTargetSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.accessibilityCoachingTips)
        .accessibilityValue(isExpanded ? AppText.commonExpanded : AppText.commonCollapsed)
        .accessibilityHint(isExpanded ? AppText.accessibilityCollapsesCoachingTips : AppText.accessibilityExpandsCoachingTips)
    }

    func toggleCoachingTips() {
        if isExpanded {
            isExpanded = false
            return
        }
        weightPhases = analyticsViewModel.loadCardPhases(
            for: model.id,
            hasWeight: model.hasWeight
        )
        guard !weightPhases.isEmpty else { return }
        isExpanded = true
    }

    /// Circular coaching glyph matching the completed card's reset-button size.
    var coachingTipBadge: some View {
        CardActionCircleButtonVisual(
            iconSize: ExerciseCardLayout.ResetButton.iconSize,
            discSize: ExerciseCardLayout.ResetButton.size,
            frameSize: ExerciseCardLayout.ResetButton.size,
            surface: .filled()
        ) {
            imageProvider("tip_coaching_2")
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
                        IdlePauseButton()
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
            .accessibilityLabel(AppText.accessibilityStartExercise)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Expanded Content

private extension IdleActiveCardModelView {

    var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = lastRunPresentation.date {
                Text(AppText.trainingLastTraining(date: date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits).locale(locale))))
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
        let showsCoaching = !lastRunPresentation.setProgress.isEmpty
        return SetTilesRow(
            setProgress: lastRunPresentation.setProgress,
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
