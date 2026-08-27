import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

struct BilateralSetLayoutMetrics: Equatable {
    let leftColumnWidth: CGFloat
    let rightColumnWidth: CGFloat

    init(containerWidth: CGFloat) {
        let safeWidth = max(containerWidth, 0)
        let badgeSlotWidth = AppStyle.Layout.setRowBadgeSize
            + AppStyle.Layout.bilateralColumnSpacing
        let sharedValueWidth = max((safeWidth - badgeSlotWidth) / 2, 0)

        leftColumnWidth = sharedValueWidth + badgeSlotWidth
        rightColumnWidth = sharedValueWidth
    }
}

/// Keeps the bilateral columns width-aware without making their card
/// vertically greedy. A `GeometryReader` needs an explicit height and was
/// previously responsible for the unused space below the final set row.
private struct BilateralColumnsLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let proposedWidth = proposal.width
            ?? subviews.reduce(0) {
                $0 + $1.sizeThatFits(.unspecified).width
            }
        let metrics = BilateralSetLayoutMetrics(containerWidth: proposedWidth)
        let leftSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: metrics.leftColumnWidth, height: nil)
        )
        let rightSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: metrics.rightColumnWidth, height: nil)
        )

        return CGSize(
            width: proposedWidth,
            height: max(leftSize.height, rightSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }

        let metrics = BilateralSetLayoutMetrics(containerWidth: bounds.width)
        subviews[0].place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: metrics.leftColumnWidth,
                height: bounds.height
            )
        )
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX
                    + metrics.leftColumnWidth,
                y: bounds.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: metrics.rightColumnWidth,
                height: bounds.height
            )
        )
    }
}

struct BilateralPairLayoutMetrics: Equatable {
    let leftWidth: CGFloat
    let rightWidth: CGFloat
    let resolvedPairSpacing: CGFloat

    init(
        containerWidth: CGFloat,
        leftIdealWidth: CGFloat,
        rightIdealWidth: CGFloat,
        badgeSlotWidth: CGFloat,
        minimumPairSpacing: CGFloat
    ) {
        let safeWidth = max(containerWidth, 0)
        let idealWidth = leftIdealWidth
            + minimumPairSpacing
            + rightIdealWidth

        if safeWidth >= idealWidth {
            leftWidth = leftIdealWidth
            rightWidth = rightIdealWidth
            resolvedPairSpacing = safeWidth
                - leftIdealWidth
                - rightIdealWidth
        } else {
            let sharedValueWidth = max(
                (safeWidth - minimumPairSpacing - badgeSlotWidth) / 2,
                0
            )
            leftWidth = sharedValueWidth + badgeSlotWidth
            rightWidth = sharedValueWidth
            resolvedPairSpacing = minimumPairSpacing
        }
    }
}

/// Anchors Left and Right to the row's outer insets while keeping each side's
/// metric group content-sized. Only the final tight fallback compresses both
/// value groups symmetrically.
private struct BilateralPairRowLayout: Layout {
    let metricSpacing: CGFloat
    let pairSpacing: CGFloat
    let allowsCompression: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let leftIdeal = subviews[0].sizeThatFits(.unspecified)
        let rightIdeal = subviews[1].sizeThatFits(.unspecified)
        let idealWidth = leftIdeal.width + pairSpacing + rightIdeal.width
        let proposedWidth = max(proposal.width ?? idealWidth, 0)
        let width = allowsCompression
            ? proposedWidth
            : max(proposedWidth, idealWidth)
        let metrics = layoutMetrics(
            containerWidth: width,
            leftIdealWidth: leftIdeal.width,
            rightIdealWidth: rightIdeal.width
        )
        let leftSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: metrics.leftWidth, height: nil)
        )
        let rightSize = subviews[1].sizeThatFits(
            ProposedViewSize(width: metrics.rightWidth, height: nil)
        )

        return CGSize(
            width: width,
            height: max(leftSize.height, rightSize.height)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }

        let leftIdeal = subviews[0].sizeThatFits(.unspecified)
        let rightIdeal = subviews[1].sizeThatFits(.unspecified)
        let metrics = layoutMetrics(
            containerWidth: bounds.width,
            leftIdealWidth: leftIdeal.width,
            rightIdealWidth: rightIdeal.width
        )

        subviews[0].place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: metrics.leftWidth,
                height: nil
            )
        )
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX
                    + metrics.leftWidth
                    + metrics.resolvedPairSpacing,
                y: bounds.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: metrics.rightWidth,
                height: nil
            )
        )
    }

    private func layoutMetrics(
        containerWidth: CGFloat,
        leftIdealWidth: CGFloat,
        rightIdealWidth: CGFloat
    ) -> BilateralPairLayoutMetrics {
        let badgeSlotWidth = AppStyle.Layout.setRowBadgeSize + metricSpacing
        return BilateralPairLayoutMetrics(
            containerWidth: containerWidth,
            leftIdealWidth: leftIdealWidth,
            rightIdealWidth: rightIdealWidth,
            badgeSlotWidth: badgeSlotWidth,
            minimumPairSpacing: pairSpacing
        )
    }
}

private struct BilateralSetPair: Identifiable {
    let id: SetProgress.ID
    let leftIndex: Int
    let rightIndex: Int
}

enum SetRowPlacement: Equatable {
    case standard
    case bilateralLeft
    case bilateralRight

    var isBilateral: Bool {
        self != .standard
    }

    var showsSetNumber: Bool {
        self != .bilateralRight
    }
}

enum SetRowHighlightResolver {
    static func isActiveSetNumber(
        rowIndex: Int,
        progress: SetProgress,
        activeSetIndex: Int,
        allProgress: [SetProgress],
        placement: SetRowPlacement
    ) -> Bool {
        guard placement.isBilateral else {
            return rowIndex == activeSetIndex
        }
        guard allProgress.indices.contains(activeSetIndex),
              let logicalSetIndex = progress.logicalSetIndex,
              let activeLogicalSetIndex = allProgress[activeSetIndex].logicalSetIndex else {
            return rowIndex == activeSetIndex
        }
        return logicalSetIndex == activeLogicalSetIndex
    }
}

public struct SimpleActiveSetView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let exercise: Exercise
    @Binding public var setProgress: [SetProgress]
    public var viewModel: ActiveSetViewModel

    public init(
        exercise: Exercise,
        setProgress: Binding<[SetProgress]>,
        viewModel: ActiveSetViewModel
    ) {
        self.exercise = exercise
        _setProgress = setProgress
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if exercise.executionMode == .bilateral {
                bilateralContent
            } else {
                standardContent
            }
        }
        .padding(.horizontal, AppStyle.DeviceLayout.cardPadding)
        .padding(.vertical, AppStyle.Layout.activeSetVerticalPadding)
    }

    private var standardContent: some View {
        VStack(spacing: AppStyle.Layout.activeSetRowSpacing) {
            ForEach(Array(setProgress.enumerated()), id: \.element.id) { index, progress in
                SetRowView(
                    index: index,
                    progress: progress,
                    exercise: exercise,
                    viewModel: viewModel,
                    placement: .standard
                )
                .id(progress.id)
            }
        }
    }

    private var bilateralContent: some View {
        VStack(spacing: AppStyle.Layout.activeSetRowSpacing) {
            bilateralHeader

            ForEach(bilateralPairs) { pair in
                bilateralPairRow(
                    leftIndex: pair.leftIndex,
                    rightIndex: pair.rightIndex
                )
                .id(pair.id)
            }
        }
        .padding(.horizontal, AppStyle.DeviceLayout.cardPadding)
    }

    private var bilateralHeader: some View {
        BilateralColumnsLayout {
            sideHeader(.left, placement: .bilateralLeft)
            sideHeader(.right, placement: .bilateralRight)
        }
        .padding(.bottom, AppStyle.Padding.cardVertical)
    }

    private func sideHeader(
        _ side: ExerciseSide,
        placement: SetRowPlacement
    ) -> some View {
        HStack(spacing: 0) {
            if placement == .bilateralLeft {
                Color.clear
                    .frame(
                        width: AppStyle.Layout.setRowBadgeSize
                            + AppStyle.Layout.bilateralColumnSpacing,
                        height: AppStyle.Layout.bilateralSideHeaderSize
                    )
            }

            Text(verbatim: side == .left ? "L" : "R")
                .font(AppStyle.Font.bilateralSideHeader)
                .foregroundColor(appColorTheme.accent.glow)
                .frame(
                    width: AppStyle.Layout.bilateralSideHeaderSize,
                    height: AppStyle.Layout.bilateralSideHeaderSize
                )
                .overlay {
                    Circle().stroke(
                        appColorTheme.accent.glow,
                        lineWidth: AppStyle.Layout.bilateralHeaderStrokeWidth
                    )
                }
                .accessibilityLabel(side == .left ? AppText.accessibilityLeft : AppText.accessibilityRight)
                .accessibilityIdentifier(TrainingIDs.sideHeader(side))
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func bilateralPairRow(
        leftIndex: Int,
        rightIndex: Int
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            pairRow(
                leftIndex: leftIndex,
                rightIndex: rightIndex,
                sizing: .standard,
                metricSpacing: AppStyle.Layout.bilateralMetricSpacingComfortable,
                pairSpacing: AppStyle.Layout.bilateralPairSpacingComfortable
            )

            pairRow(
                leftIndex: leftIndex,
                rightIndex: rightIndex,
                sizing: .bilateralComfortable,
                metricSpacing: AppStyle.Layout.bilateralMetricSpacingComfortable,
                pairSpacing: AppStyle.Layout.bilateralPairSpacingComfortable
            )

            pairRow(
                leftIndex: leftIndex,
                rightIndex: rightIndex,
                sizing: .bilateralCompact,
                metricSpacing: AppStyle.Layout.bilateralMetricSpacingCompact,
                pairSpacing: AppStyle.Layout.bilateralPairSpacingCompact
            )

            pairRow(
                leftIndex: leftIndex,
                rightIndex: rightIndex,
                sizing: .bilateralTight,
                metricSpacing: AppStyle.Layout.bilateralMetricSpacingTight,
                pairSpacing: AppStyle.Layout.bilateralPairSpacingTight
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func pairRow(
        leftIndex: Int,
        rightIndex: Int,
        sizing: SetRowMetricSizing,
        metricSpacing: CGFloat,
        pairSpacing: CGFloat
    ) -> some View {
        BilateralPairRowLayout(
            metricSpacing: metricSpacing,
            pairSpacing: pairSpacing,
            allowsCompression: sizing == .bilateralTight
        ) {
            SetRowView(
                index: leftIndex,
                progress: setProgress[leftIndex],
                exercise: exercise,
                viewModel: viewModel,
                placement: .bilateralLeft,
                bilateralMetricSizing: sizing,
                bilateralMetricSpacing: metricSpacing
            )

            SetRowView(
                index: rightIndex,
                progress: setProgress[rightIndex],
                exercise: exercise,
                viewModel: viewModel,
                placement: .bilateralRight,
                bilateralMetricSizing: sizing,
                bilateralMetricSpacing: metricSpacing
            )
        }
    }

    private var bilateralPairs: [BilateralSetPair] {
        setProgress.indices.compactMap { leftIndex in
            guard setProgress[leftIndex].side == .left,
                  let logicalSetIndex = setProgress[leftIndex].logicalSetIndex,
                  let rightIndex = setProgress.indices.first(where: {
                      setProgress[$0].side == .right
                          && setProgress[$0].logicalSetIndex == logicalSetIndex
                  }) else {
                return nil
            }
            return BilateralSetPair(
                id: setProgress[leftIndex].id,
                leftIndex: leftIndex,
                rightIndex: rightIndex
            )
        }
    }
}

// MARK: - SetRowChip Modifier

public struct SetRowChipStyle: ViewModifier {
    public let minWidth: CGFloat
    public let horizontalPadding: CGFloat
    /// Outline colour, or `nil` for no outline. The weight chip renders bare
    /// text while the reps field keeps its box and tints the outline for the
    /// active set, so the two can no longer share one hard-coded border.
    public let borderColor: Color?
    /// `nil` keeps the shared chip typography. The weight chip overrides it to
    /// match the idle card's weight value.
    public let font: Font?

    public init(
        minWidth: CGFloat,
        horizontalPadding: CGFloat = AppStyle.Layout.setRowChipHorizontalPadding,
        borderColor: Color? = AppStyle.Color.gray,
        font: Font? = nil
    ) {
        self.minWidth = minWidth
        self.horizontalPadding = horizontalPadding
        self.borderColor = borderColor
        self.font = font
    }

    public func body(content: Content) -> some View {
        content
            .font(font ?? AppStyle.Font.tileLabel)
            .foregroundColor(AppStyle.Color.white)
            .frame(minWidth: minWidth, minHeight: 24)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 4)
            // No fill: the screen backdrop reads through the chip. The reps
            // field still shows its outline, so it stays a recognisable input
            // box without sitting on an opaque plate.
            .overlay {
                if let borderColor {
                    // `.continuous` to match the Done button and the timer card;
                    // plain circular corners read visibly rounder at this size.
                    RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.defaultButton,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: 1)
                }
            }
    }
}

public extension View {
    func setRowChipStyle(
        minWidth: CGFloat,
        horizontalPadding: CGFloat = AppStyle.Layout.setRowChipHorizontalPadding,
        borderColor: Color? = AppStyle.Color.gray,
        font: Font? = nil
    ) -> some View {
        modifier(
            SetRowChipStyle(
                minWidth: minWidth,
                horizontalPadding: horizontalPadding,
                borderColor: borderColor,
                font: font
            )
        )
    }
}

// MARK: - Unified Set Row

private enum SetRowMetricSizing: Equatable {
    case standard
    case standardCompact
    case bilateralComfortable
    case bilateralCompact
    case bilateralTight

    var horizontalPadding: CGFloat {
        switch self {
        case .standard, .bilateralComfortable:
            AppStyle.Layout.setRowChipHorizontalPadding
        case .standardCompact, .bilateralCompact:
            AppStyle.Layout.bilateralMetricChipHorizontalPadding
        case .bilateralTight:
            AppStyle.Layout.bilateralMetricChipHorizontalPaddingTight
        }
    }

    var isStandard: Bool {
        self == .standard || self == .standardCompact
    }
}

private struct SetRowView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    let index: Int
    let progress: SetProgress
    let exercise: Exercise
    var viewModel: ActiveSetViewModel
    let placement: SetRowPlacement
    var bilateralMetricSizing: SetRowMetricSizing = .bilateralCompact
    var bilateralMetricSpacing: CGFloat = AppStyle.Layout.bilateralMetricSpacingCompact

    private var compact: Bool {
        placement.isBilateral
    }

    private var isPending: Bool {
        progress.status == .notStarted || progress.status == .inProgress
    }

    private var canRecordAchievement: Bool {
        isPending
            && index == viewModel.activeSetIndex
            && index == viewModel.currentSet
            && viewModel.isSetInProgress
            && !viewModel.isLastSetCompleted
    }

    private var isMetricInteractionEnabled: Bool {
        !isPending || canRecordAchievement
    }

    private var isActiveSetNumber: Bool {
        SetRowHighlightResolver.isActiveSetNumber(
            rowIndex: index,
            progress: progress,
            activeSetIndex: viewModel.activeSetIndex,
            allProgress: viewModel.setProgress,
            placement: placement
        )
    }

    var body: some View {
        Group {
            if compact {
                bilateralRow
            } else {
                standardRow
            }
        }
    }

    private var standardRow: some View {
        ViewThatFits(in: .horizontal) {
            standardRow(sizing: .standard)
            standardRow(sizing: .standardCompact)
        }
    }

    private func standardRow(sizing: SetRowMetricSizing) -> some View {
        // Baseline-aligned, not centre-aligned: the weight is one text run of
        // 20pt value plus 13pt unit sharing a baseline that sits well below the
        // line box's centre, while "of N" is a standalone 13pt label. Centring
        // put the two secondary labels at different heights.
        HStack(
            alignment: .firstTextBaseline,
            spacing: sizing == .standardCompact
                ? AppStyle.Layout.bilateralMetricSpacingCompact
                : AppStyle.DeviceLayout.cardSpacing
        ) {
            setNumberBadge

            if exercise.hasWeight {
                weightChip(sizing: sizing)
            }

            repsChip(sizing: sizing)

            repsLabel(sizing: sizing)

        }
        .padding(
            .horizontal,
            sizing == .standardCompact ? 0 : AppStyle.DeviceLayout.cardPadding
        )
    }

    private var bilateralRow: some View {
        HStack(spacing: bilateralMetricSpacing) {
            if placement.showsSetNumber {
                setNumberBadge
                    .fixedSize()
            }

            metricValues(
                spacing: bilateralMetricSpacing,
                sizing: bilateralMetricSizing
            )
        }
    }

    private func metricValues(
        spacing: CGFloat,
        sizing: SetRowMetricSizing
    ) -> some View {
        HStack(spacing: spacing) {
            if exercise.hasWeight {
                weightChip(sizing: sizing)
            }

            repsChip(sizing: sizing)

            repsLabel(sizing: sizing)

        }
    }

    /// True while this row is the one being trained. Drives the accent on the set
    /// number and on the reps field's outline, which replaced the ring that used
    /// to circle the number.
    private var isActiveSetHighlight: Bool {
        isActiveSetNumber && !viewModel.quickDoneAllCompleted
    }

    private var setNumberBadge: some View {
        // The number itself carries the active state; no ring around it. The
        // frame is kept so row geometry (and the badge-size assertion in
        // BilateralTrainingTests) is unaffected by dropping the circles.
        Text(verbatim: "\((progress.logicalSetIndex ?? index) + 1)")
            .font(AppStyle.Font.setRowNumber)
            .foregroundColor(isActiveSetHighlight ? AppStyle.Color.muscleArtworkRimBright : AppStyle.Color.white)
            .frame(
                width: AppStyle.Layout.setRowBadgeSize,
                height: AppStyle.Layout.setRowBadgeSize
            )
    }

    private func weightChip(sizing: SetRowMetricSizing) -> some View {
        Button(action: handleMetricTap) {
            // Value and unit are separate runs so the unit can take the idle
            // card's dimmer, smaller treatment. `displayWeight` returns one
            // combined "46 kg" string and cannot be styled per part.
            {
                let value = Text(verbatim: WeightFormatter.format(progress.weight, locale: locale))
                    .font(AppStyle.Font.idleWeightValue)
                    .foregroundColor(AppStyle.Color.white)
                // The tight bilateral layout drops the unit entirely rather than
                // appending an empty styled run.
                guard sizing != .bilateralTight else { return value }
                return value + Text(verbatim: " kg")
                    .font(AppStyle.Font.cardMetricUnit)
                    .foregroundColor(AppStyle.Color.idleMetricUnit)
            }()
                .lineLimit(1)
                .minimumScaleFactor(AppStyle.Layout.bilateralMetricMinimumScaleFactor)
                .setRowChipStyle(
                    minWidth: sizing == .standard
                        ? AppStyle.DeviceLayout.setRowWeightMinWidth
                        : 0,
                    horizontalPadding: sizing.horizontalPadding,
                    borderColor: nil
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.defaultButton,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isMetricInteractionEnabled)
        .accessibilityLabel(isPending ? AppText.accessibilityRecordSetResult : AppText.accessibilityEditWeight)
        .accessibilityValue(weightAccessibilityValue)
    }

    private func repsChip(sizing: SetRowMetricSizing) -> some View {
        Button(action: handleMetricTap) {
            Text(verbatim: !isPending ? "\(progress.currentReps)" : "")
                // Only the value dims on inactive rows — the outline keeps full
                // strength so every set stays visible as an input box.
                .frame(
                    minWidth: !sizing.isStandard
                        ? AppStyle.Layout.bilateralRepsChipContentMinWidth
                        : nil
                )
                .setRowChipStyle(
                    minWidth: !sizing.isStandard
                        ? 0
                        : (exercise.hasWeight
                            ? (sizing == .standardCompact ? 30 : 35)
                            : AppStyle.DeviceLayout.setRowRepsMinWidth),
                    horizontalPadding: sizing.horizontalPadding,
                    // Same surface as before; only the outline changes, so the
                    // active row is marked here just like its set number.
                    borderColor: isActiveSetHighlight
                        ? AppStyle.Color.muscleArtworkRim
                        : AppStyle.Color.gray,
                    font: AppStyle.Font.cardValueBold
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.defaultButton,
                        style: .continuous
                    )
                )
        }
        .fixedSize(horizontal: !sizing.isStandard, vertical: false)
        .buttonStyle(PlainButtonStyle())
        .disabled(!isMetricInteractionEnabled)
        .accessibilityLabel(isPending ? AppText.accessibilityRecordSetResult : AppText.accessibilityEditRepetitions)
        .accessibilityValue(repsAccessibilityValue)
        .accessibilityIdentifier(repsAccessibilityIdentifier)
    }

    private var weightAccessibilityValue: Text {
        if isPending {
            Text(AppText.accessibilityTarget(value: WeightFormatter.displayWeight(exercise.weight, locale: locale)))
        } else {
            Text(verbatim: WeightFormatter.displayWeight(progress.weight, locale: locale))
        }
    }

    private var repsAccessibilityValue: Text {
        if isPending {
            Text(AppText.accessibilityTarget(value: exercise.reps.formatted(.number.locale(locale))))
        } else {
            Text(verbatim: progress.currentReps.formatted(.number.locale(locale)))
        }
    }

    private func handleMetricTap() {
        if isPending {
            viewModel.startRecordingAchievement(index: index)
        } else {
            viewModel.startEditingSet(index: index, mode: .edit)
        }
    }

    private func repsLabel(sizing: SetRowMetricSizing) -> some View {
        Group {
            if sizing == .bilateralTight {
                Text(verbatim: "/\(exercise.reps)")
            } else {
                Text(AppText.exerciseOfCount(count: exercise.reps))
            }
        }
            // Same treatment as the "kg" unit beside the weight, so the two
            // secondary labels in a row read as one tier.
            .font(AppStyle.Font.cardMetricUnit)
            .foregroundColor(AppStyle.Color.idleMetricUnit)
            .lineLimit(1)
            .minimumScaleFactor(
                compact
                    ? AppStyle.Layout.bilateralMetricMinimumScaleFactor
                    : 0.6
            )
            .fixedSize(horizontal: !compact, vertical: false)
    }

    private var repsAccessibilityIdentifier: String {
        guard let side = progress.side else {
            return TrainingIDs.repsField(set: index)
        }
        return TrainingIDs.repsField(
            logicalSet: progress.logicalSetIndex ?? index,
            side: side
        )
    }

}
