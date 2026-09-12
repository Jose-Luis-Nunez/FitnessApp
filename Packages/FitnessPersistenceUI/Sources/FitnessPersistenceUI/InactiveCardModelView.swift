import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessResources
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

struct LatestSetProgressCardState {
    private(set) var setProgress: [SetProgress] = []

    /// A failed read may reveal previously loaded data, but it must never make
    /// an empty details area look like a successful expansion.
    mutating func apply(_ outcome: LatestAnalyticsEntryLoadOutcome) -> Bool {
        switch outcome {
        case let .loaded(entry):
            setProgress = entry?.setProgress ?? []
        case .failed:
            break
        }
        return !setProgress.isEmpty
    }
}

struct SessionImprovementCardState {
    private(set) var improvement: SessionImprovement?

    /// A failed read must never look like "did not improve": the previous value
    /// is kept so a later revision can retry instead of caching an empty state.
    mutating func apply(_ outcome: SessionImprovementLoadOutcome) {
        switch outcome {
        case let .loaded(value):
            improvement = value
        case .failed:
            break
        }
    }
}

/// Completed (inactive) card variant rendered against a live
/// `@Bindable ExerciseModel`. The data source is the SwiftData `@Model` instance —
/// all edits propagate automatically without snapshot sync (ADR-0001). Analytics
/// refreshes carry an Exercise id, so unrelated cards keep their staged analytics state.
///
/// SPI marker: see `ExerciseCardModelView`.
@_spi(PersistenceUI)
public struct InactiveCardModelView: View {
    @Bindable public var model: ExerciseModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel
    public let onReset: ((Exercise) -> Void)?
    public let isResetEnabled: Bool
    let imageProvider: (String) -> Image

    @State private var isShowingAnalytics = false
    @State private var isExpanded = false
    @State private var latestSetPresentation = LatestSetProgressCardState()
    @State private var improvementPresentation = SessionImprovementCardState()
    @State private var analyticsRevision: ExerciseAnalyticsCacheRevision
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

    public init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        onReset: ((Exercise) -> Void)?,
        isResetEnabled: Bool
    ) {
        self.init(
            model: model,
            onEdit: onEdit,
            isEditable: isEditable,
            analyticsViewModel: analyticsViewModel,
            onReset: onReset,
            isResetEnabled: isResetEnabled,
            imageProvider: { Image($0) }
        )
    }

    init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        onReset: ((Exercise) -> Void)?,
        isResetEnabled: Bool,
        // Mirrors `IdleActiveCardModelView`: the expanded set-tile row is only
        // reachable through a tap, which a snapshot cannot perform.
        initiallyExpanded: Bool = false,
        imageProvider: @escaping (String) -> Image
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.onReset = onReset
        self.isResetEnabled = isResetEnabled
        self.imageProvider = imageProvider
        self._isExpanded = State(initialValue: initiallyExpanded)
        self._analyticsRevision = State(
            initialValue: analyticsViewModel.revisionSource(for: model.id)
        )
    }

    private func loadLatestSetProgress() -> Bool {
        latestSetPresentation.apply(
            analyticsViewModel.loadLatestEntry(for: model.id)
        )
    }

    private func loadImprovement() {
        improvementPresentation.apply(
            analyticsViewModel.loadSessionImprovement(
                for: model.id,
                hasWeight: model.hasWeight
            )
        )
    }

    private func toggleExpansion() {
        if isExpanded {
            isExpanded = false
            return
        }
        guard loadLatestSetProgress() else { return }
        isExpanded = true
    }

    private let theme = CardTheme.inactiveOnIdle

    public var body: some View {
        CardShell(theme: theme, leading: {
            categoryIconView
        }, trailing: {
            checkmarkTrailing
        }, titleContent: {
            titleSection
        }, expandedContent: {
            if isExpanded {
                VStack(spacing: 0) {
                    Spacer().frame(height: 10)
                    setTilesRow.frame(height: ExerciseCardLayout.SetTiles.rowHeight)
                    Spacer().frame(height: 4)
                }
                .padding(.horizontal, AppStyle.Padding.card)
            }
        })
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { toggleExpansion() }
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel)
        }
        // Synchronous on purpose, not `.task`. `.task` runs its body in a
        // scheduled Task, so the read can resume after the surrounding
        // `ModelContext` is gone and then trap on a destroyed `model` — which is
        // exactly what the collapsed-card snapshot caught. `onAppear` plus an
        // id-change hook covers the same two triggers while the model is
        // guaranteed alive. The read is affordable inline because
        // `loadRecentEntries` is a bounded, paged fetch rather than a full
        // history read.
        .onAppear {
            loadImprovement()
            // Only a card that starts expanded needs its set details fetched
            // here; the normal path loads them in `toggleExpansion`. Mirrors the
            // revision handler below, including collapsing again on a failed
            // read rather than showing an empty details area.
            //
            // The success path is covered by the `expandedSetTiles` snapshot;
            // the collapse rule itself by `LatestSetProgressCardState`'s own
            // tests. A render-based test of this line could only assert that a
            // read happened, which is not the rule worth protecting.
            if isExpanded { isExpanded = loadLatestSetProgress() }
        }
        .onChange(of: model.id) { loadImprovement() }
        .onChange(of: analyticsRevision.value) {
            loadImprovement()
            if isExpanded {
                isExpanded = loadLatestSetProgress()
            }
        }
    }
}

// MARK: - Header

private extension InactiveCardModelView {

    var categoryIconView: some View {
        ExerciseCardArtworkView(
            image: imageProvider(appColorTheme.muscleIconName(for: model.displayIconName)),
            size: AppStyle.Layout.idleActiveCardIconSize,
            alignment: model.iconAlignment
        )
            .contentShape(Rectangle())
            .onTapGesture {
                // Tapping the muscle icon opens the reused "Edit Seat" sheet so the
                // seat stays adjustable after the exercise is finished. Expansion
                // remains reachable via the title chevron and the checkmark.
                // `isEditable` is retained here (unlike the active card) because the
                // completed card is also hosted in read-only/grid contexts where the
                // icon must keep its expand/navigate behavior.
                if isEditable && model.allowsSeatEditing {
                    onEdit(model.toDomain(), .seat)
                } else {
                    toggleExpansion()
                }
            }
            .accessibilityIdentifier(ExerciseCardIDs.seatEditIcon(model.id))
    }

    /// Trailing column. Two shapes, because the two header states need different
    /// things from it.
    ///
    /// With a gain to show, it is built on the *same* grid as the metric column
    /// on the left: a title-height row, then a block of
    /// `improvementColumnHeight` whose first line is a reserved stand-in for the
    /// gain value and whose second line is the label. Because both columns share
    /// that rhythm and are centred in the same header row, "Details" lands on
    /// the "now …" line by construction — no tuned offset that would drift when
    /// a font or a height changes.
    ///
    /// With nothing to show, "Details" has moved under "Completed" on the left,
    /// so this column carries only the checkmark and lets the header row centre
    /// it. Reproducing the grid here would pin it to the top for no reason.
    @ViewBuilder
    var checkmarkTrailing: some View {
        if hasImprovement {
            improvementCheckmarkColumn
        } else {
            checkmarkCircle
                // The state is already announced by `completedColumn`'s label,
                // which also carries the expansion action; a second element
                // saying the same thing would just be another stop.
                .accessibilityHidden(true)
                .frame(width: ExerciseCardLayout.TrailingControl.columnWidth)
                .contentShape(Rectangle())
                .onTapGesture { toggleExpansion() }
        }
    }

    var improvementCheckmarkColumn: some View {
        VStack(spacing: 4) {
            // Reserves exactly one title line. The checkmark is taller and is
            // drawn as an overlay, so it can extend downward without pushing the
            // grid apart.
            Text(verbatim: " ")
                .font(theme.titleFont)
                .hidden()
                .overlay(alignment: .top) { checkmarkCircle }

            VStack(spacing: improvementLineSpacing) {
                // Stand-in for the gain line on the idle card's value row.
                Text(verbatim: "+0")
                    .font(AppStyle.Font.rowValue)
                    .hidden()
                    .frame(height: AppStyle.Layout.idleMetricContentRowHeight)

                // The column is now a fixed width, so a longer localisation of
                // "Details" shrinks instead of truncating or widening the column.
                Text(AppText.commonDetails)
                    .font(AppStyle.Font.rowSecondary)
                    .foregroundColor(AppStyle.Color.rowSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: AppStyle.Layout.idleMetricFooterRowHeight)
            }
            .frame(height: improvementColumnHeight)
        }
        // No disclosure chevron under "Details" by design. It used to hang below
        // the label as an overlay and read as if the card bulged past its own
        // bottom edge; the word "Details" carries the affordance instead, and the
        // whole card is the tap target. Do not reinstate it without revisiting
        // that — it was removed on purpose, not lost.
        //
        // Fixed, not a minimum: the reset button below is centred in a column of
        // exactly this width, and the two only line up if this one cannot grow
        // with the width of the word "Details". See
        // `ExerciseCardLayout.TrailingControl`.
        .frame(width: ExerciseCardLayout.TrailingControl.columnWidth)
        .contentShape(Rectangle())
        .onTapGesture { toggleExpansion() }
        // The tap target is a bare shape, so without this the expand affordance
        // exists only for sighted pointer input.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(AppText.commonDetails))
        .accessibilityAction { toggleExpansion() }
    }

    var checkmarkCircle: some View {
        CardActionCircleButtonVisual(
            iconSize: 14,
            discSize: AppStyle.Layout.idlePlayButtonSize,
            frameSize: AppStyle.Layout.idlePlayButtonGlowSize,
            surface: .clear
        ) {
            SharpCheckmark()
                .stroke(
                    appColorTheme.accent.idleAccentFill,
                    style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter)
                )
                .frame(width: 14, height: 11)
        }
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: model.name)
                .font(theme.titleFont)
                .foregroundColor(theme.titleColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(ExerciseIDs.nameLabel)
                .onTapGesture {
                    if isEditable { onEdit(model.toDomain(), .full) }
                }

            improvementRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Improvement Row

private extension InactiveCardModelView {

    /// Whether the card has a gain to show, for the trailing column's benefit —
    /// its two shapes are chosen by this. `improvementRow` asks the same
    /// question inline because it needs the unwrapped value, not just the answer.
    var hasImprovement: Bool {
        guard let improvement = improvementPresentation.improvement else { return false }
        return !improvement.isEmpty
    }

    /// Mirrors the idle card's metric row geometry — a value line on
    /// `idleMetricContentRowHeight` over a footer on `idleMetricFooterRowHeight`.
    /// Both heights are held in every state, which is what keeps the completed
    /// card exactly as tall as the idle card no matter what it has to show.
    @ViewBuilder
    var improvementRow: some View {
        let improvement = improvementPresentation.improvement

        HStack(alignment: .top, spacing: 0) {
            if let improvement, !improvement.isEmpty {
                // Each present column claims an equal share and aligns leading,
                // so a lone reps gain sits on the left instead of holding the
                // reps position with an empty weight slot beside it.
                if let gain = improvement.weightGain {
                    gainColumn(
                        gain: WeightFormatter.format(gain, locale: locale),
                        unit: Text(AppText.unitKilogram),
                        footer: Text(AppText.exerciseNowWeight(
                            weight: WeightFormatter.format(improvement.currentWeight, locale: locale)
                        ))
                    )
                }

                if let gain = improvement.repsGain {
                    gainColumn(
                        gain: "\(gain)",
                        unit: Text(AppText.exerciseRepsUnit),
                        footer: Text(AppText.exerciseNowReps(reps: improvement.currentReps))
                    )
                }
            } else {
                completedColumn
            }
        }
    }

    /// Height the improvement area occupies: the idle card's value row, its
    /// gap, and its footer row. Each line is pinned to its row as well, so the
    /// "now …" line sits exactly where "Last run" sits on the idle card.
    var improvementColumnHeight: CGFloat {
        AppStyle.Layout.idleMetricContentRowHeight
            + improvementLineSpacing
            + AppStyle.Layout.idleMetricFooterRowHeight
    }

    /// "Completed" plus what the exercise was finished with, for VoiceOver only.
    /// Mirrors how the idle card states the same figures.
    var completedAccessibilityLabel: Text {
        if model.hasWeight {
            return Text(AppText.exerciseCompleted)
                + Text(verbatim: ", ")
                + Text(AppText.exerciseNowWeight(
                    weight: WeightFormatter.format(model.weight, locale: locale)
                ))
        }
        return Text(AppText.exerciseCompleted)
            + Text(verbatim: ", ")
            + Text(AppText.exerciseNowReps(reps: model.reps))
    }

    /// Gap between the value row and the footer row — the same 4pt the idle
    /// card puts between its weight and "Last run", so both footers align.
    var improvementLineSpacing: CGFloat { 4 }

    func gainColumn(gain: String, unit: Text, footer: Text) -> some View {
        VStack(alignment: .leading, spacing: improvementLineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: "+\(gain)")
                    .font(AppStyle.Font.rowValue)
                    // The scheme's idle accent, not a fixed hex: a gain has to
                    // match the play and check glyphs in every palette.
                    .foregroundColor(appColorTheme.accent.idleAccentFill.opacity(AppStyle.Opacity.rowPositiveValue))

                unit
                    .font(AppStyle.Font.rowUnit)
                    .foregroundColor(AppStyle.Color.rowUnit)
            }
            .frame(height: AppStyle.Layout.idleMetricContentRowHeight)

            footer
                .font(AppStyle.Font.rowSecondary)
                .foregroundColor(AppStyle.Color.rowSecondary)
                .frame(height: AppStyle.Layout.idleMetricFooterRowHeight)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: improvementColumnHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Nothing improved: "Completed" with "Details" beneath it, both on the left.
    ///
    /// The two lines occupy the same grid the gain columns use — value line and
    /// footer line — so the card keeps the idle card's height. Previously the
    /// value line held a hidden stand-in and "Details" sat in the trailing
    /// column opposite; with no gain to balance, that left the card's only two
    /// words on opposite edges and pinned the checkmark to the top.
    ///
    /// The finishing weight deliberately stays out of the value line: it belongs
    /// to the set tiles below, and filling the line that everywhere else carries
    /// a gain read as a gain missing its `+`.
    var completedColumn: some View {
        VStack(alignment: .leading, spacing: improvementLineSpacing) {
            // Styled as the value it is, not as a label. It sits on the line
            // that carries "+5 kg" in the other states, and at the footer's
            // 13pt grey it read as its own small print next to "Details" —
            // two greys two points apart. Deliberately not the accent colour:
            // on this card that means "you gained", which is the opposite of
            // what this state says.
            Text(AppText.exerciseCompleted)
                .font(AppStyle.Font.rowState)
                .foregroundColor(AppStyle.Color.rowSecondary)
                .frame(height: AppStyle.Layout.idleMetricContentRowHeight)

            Text(AppText.commonDetails)
                .font(AppStyle.Font.rowSecondary)
                .foregroundColor(AppStyle.Color.rowSecondary)
                .frame(height: AppStyle.Layout.idleMetricFooterRowHeight)
        }
        // One element carrying both the state and the affordance: the weight is
        // announced (a set-tile row is not reachable without expanding), and the
        // expansion the word "Details" promises is offered as an action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(completedAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggleExpansion() }
        // Same frame as `gainColumn`; both lines are pinned to the idle card's
        // rows, so "Details" shares the footer line with "Last run" over there.
        .frame(height: improvementColumnHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Set Tiles

private extension InactiveCardModelView {

    var setTilesRow: some View {
        SetTilesRow(
            setProgress: latestSetPresentation.setProgress,
            hasWeight: model.hasWeight,
            chevronColor: theme.subtitleColor.opacity(AppStyle.Opacity.separatorLine),
            // Gated on the same flag as the accessory itself: reserving the
            // column unconditionally left 52pt of dead trailing space, and
            // correspondingly narrower tiles, whenever the reset button is
            // absent.
            reservedTrailingWidth: isResetEnabled ? ExerciseCardLayout.TrailingControl.columnWidth : 0,
            visibleTileCount: AppStyle.Layout.setTileVisibleCount,
            onTap: { isShowingAnalytics = true },
            tilesAccessibilityIdentifier: ExerciseCardIDs.analytics(model.id),
            trailingAccessory: {
                if isResetEnabled {
                    ExerciseCardResetButton(image: imageProvider("repeat")) {
                        onReset?(model.toDomain())
                    }
                        .frame(width: ExerciseCardLayout.TrailingControl.columnWidth)
                }
            }
        )
    }
}

// MARK: - Sharp Checkmark

/// A checkmark drawn with straight lines and miter joins — no rounded caps,
/// giving a deliberately angular look compared to the SF Symbol variant.
private struct SharpCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Short left leg: top-left down to the valley
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.maxY))
        // Long right leg: valley up to top-right
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}
