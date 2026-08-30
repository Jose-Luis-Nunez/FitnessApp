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
        imageProvider: @escaping (String) -> Image
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.onReset = onReset
        self.isResetEnabled = isResetEnabled
        self.imageProvider = imageProvider
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
                    setTilesRow.frame(height: 60)
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
        .onAppear { loadImprovement() }
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
            image: imageProvider(appColorTheme.scheme.iconName(for: model.displayIconName)),
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

    /// Trailing column built on the *same* grid as the metric column on the
    /// left: a title-height row, then a block of `improvementColumnHeight` whose
    /// first line is a reserved stand-in for the gain value and whose second line
    /// is the label. Because both columns share that rhythm and are centred in
    /// the same header row, "Details" lands on the "now …" line by construction —
    /// no tuned offset that would drift when a font or a height changes. The
    /// same holds in the no-improvement state, where `completedColumn` reserves
    /// the gain line the same way.
    var checkmarkTrailing: some View {
        VStack(spacing: 4) {
            // Reserves exactly one title line. The checkmark is taller and is
            // drawn as an overlay, so it can extend downward without pushing the
            // grid apart.
            Text(verbatim: " ")
                .font(theme.titleFont)
                .hidden()
                .overlay(alignment: .top) { checkmarkCircle }

            VStack(spacing: improvementLineSpacing) {
                // Stand-in for the gain line: same font, so it reserves the same
                // height as "+5 kg" opposite it.
                Text(verbatim: "+0")
                    .font(AppStyle.Font.idleWeightValue)
                    .hidden()

                Text(AppText.commonDetails)
                    .font(AppStyle.Font.metricLabel)
                    .foregroundColor(AppStyle.Color.idleMetricUnit)
            }
            .frame(height: improvementColumnHeight)
        }
        // No disclosure chevron under "Details" by design. It used to hang below
        // the label as an overlay and read as if the card bulged past its own
        // bottom edge; the word "Details" carries the affordance instead, and the
        // whole card is the tap target. Do not reinstate it without revisiting
        // that — it was removed on purpose, not lost.
        //
        // Same minimum width the idle card reserves around its play button. The
        // circles are the same size, but without this the column is only as wide
        // as the word "Details" — narrower than that tap target — and since both
        // columns are pinned to the same trailing edge, the checkmark ended up
        // sitting a few points further right than the play button above it.
        .frame(minWidth: AppStyle.Layout.minimumTapTargetSize)
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
                        unit: Text(verbatim: "kg"),
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

    /// Height the improvement area occupies, matching the idle card's value row
    /// plus its footer row. Pinning the *total* rather than each line lets the
    /// gain and its "now …" line sit as tightly as the design wants while the
    /// card stays exactly as tall as an idle card.
    var improvementColumnHeight: CGFloat {
        AppStyle.Layout.idleMetricContentRowHeight
            + improvementLineSpacing
            + AppStyle.Layout.idleMetricFooterRowHeight
    }

    /// Mirrors `IdleActiveCardModelView.weightValue`: weight plus unit, or
    /// "sets x reps" for a bodyweight exercise. Muted rather than white — the
    /// exercise is done, so the number is a record, not the next thing to do.
    @ViewBuilder
    var finishedValue: some View {
        if model.hasWeight {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: WeightFormatter.format(model.weight, locale: locale))
                    .font(AppStyle.Font.idleWeightValue)
                    .foregroundColor(theme.subtitleColor)

                Text(verbatim: "kg")
                    .font(AppStyle.Font.cardMetricUnit)
                    .foregroundColor(AppStyle.Color.idleMetricUnit)
            }
            .fixedSize()
        } else {
            (
                Text(verbatim: "\(model.sets)").font(AppStyle.Font.idleWeightValue)
                    + Text(verbatim: "x").font(AppStyle.Font.idleRepsSeparator)
                    + Text(verbatim: "\(model.reps)").font(AppStyle.Font.idleWeightValue)
            )
            .foregroundColor(theme.subtitleColor)
            .lineLimit(1)
            .fixedSize()
        }
    }

    /// Gap between the gain line and its "now …" line. Tuned against the design
    /// rather than derived from a token: it is a one-off relation between these
    /// two specific lines, not a design-system spacing.
    var improvementLineSpacing: CGFloat { 5 }

    func gainColumn(gain: String, unit: Text, footer: Text) -> some View {
        VStack(alignment: .leading, spacing: improvementLineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: "+\(gain)")
                    .font(AppStyle.Font.idleWeightValue)
                    .foregroundColor(appColorTheme.accent.idleAccentFill)

                unit
                    .font(AppStyle.Font.cardMetricUnit)
                    .foregroundColor(AppStyle.Color.idleMetricUnit)
            }

            footer
                .font(AppStyle.Font.cardMetricUnit)
                .foregroundColor(AppStyle.Color.idleMetricUnit)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: improvementColumnHeight, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Nothing improved. Same two-line grid as `gainColumn` and
    /// `checkmarkTrailing`, so "Completed" lands on the footer line level with
    /// "Details" opposite it.
    ///
    /// The value line carries what the exercise was finished with, rendered the
    /// same way the idle card renders it. It used to be a hidden `+0` holding the
    /// line open, which kept the card the right height but left a gap exactly
    /// where every other card shows its number — the card read as padded rather
    /// than finished. Filling the line keeps the height and removes the gap.
    var completedColumn: some View {
        VStack(alignment: .leading, spacing: improvementLineSpacing) {
            finishedValue

            Text(AppText.exerciseCompleted)
                .font(AppStyle.Font.cardMetricUnit)
                .foregroundColor(AppStyle.Color.idleMetricUnit)
        }
        // Same frame as `gainColumn`, centred rather than top-aligned: the
        // reserved block is taller than its two lines, and every other column
        // centres inside it. Top-aligning lifted "Completed" 13pt above the
        // footer line it is meant to share with "Details".
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
            reservedTrailingWidth: isResetEnabled ? ExerciseCardLayout.ResetButton.size : 0,
            onTap: { isShowingAnalytics = true },
            trailingAccessory: {
                if isResetEnabled {
                    ExerciseCardResetButton { onReset?(model.toDomain()) }
                }
            }
        )
        .accessibilityIdentifier(ExerciseCardIDs.analytics(model.id))
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
