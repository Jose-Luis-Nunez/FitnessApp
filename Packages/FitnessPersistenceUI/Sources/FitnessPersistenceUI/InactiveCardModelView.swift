import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Completed (inactive) card variant rendered against a live
/// `@Bindable ExerciseModel`. The data source is the SwiftData `@Model` instance —
/// all edits propagate automatically without snapshot sync (ADR-0001). Still keeps
/// the `analyticsViewModel.changeCount` polling pattern; that will be resolved in
/// a later step in favor of direct `@Observable` tracking.
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

    @State private var isShowingAnalytics = false
    @State private var isExpanded = false
    @State private var cachedSetProgress: [SetProgress] = []
    @AppStorage(DefaultIconColorScheme.storageKey) private var iconColorScheme: DefaultIconColorScheme = .green

    public init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel,
        onReset: ((Exercise) -> Void)?,
        isResetEnabled: Bool
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
        self.onReset = onReset
        self.isResetEnabled = isResetEnabled
    }

    private func refreshSetProgress() {
        let latestEntry = analyticsViewModel
            .loadAnalytics(for: model.id)
            .max(by: { $0.date < $1.date })
        cachedSetProgress = latestEntry?.setProgress ?? []
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
        // The idle card's width is content-driven by its metric row (Weight | Seat
        // | Data), whose minimum width is ~400pt including card padding. On
        // narrow screens (iPhone 17, 402pt) that overflows the screen slightly so the
        // idle card reaches closer to the edges; on wide screens (16 Pro Max) it fits
        // within the standard margin. The completed card has sparse content and would
        // otherwise sit at the standard margin only — narrower than the idle card on
        // narrow screens. Matching the idle card's content minimum width here makes
        // the two cards render identically on every device (overflow on narrow, fill
        // on wide) instead of using a device-dependent fixed inset.
        .frame(minWidth: AppStyle.Layout.idleCardContentMinWidth, maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel)
        }
        .onAppear { refreshSetProgress() }
        .onChange(of: analyticsViewModel.changeCount) { _, _ in
            refreshSetProgress()
        }
    }
}

// MARK: - Header

private extension InactiveCardModelView {

    var categoryIconView: some View {
        Image(iconColorScheme.iconName(for: model.displayIconName))
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: AppStyle.Layout.idleCategoryIconSize, height: AppStyle.Layout.idleCategoryIconSize, alignment: model.iconAlignment)
            .clipped()
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
                    isExpanded.toggle()
                }
            }
            .accessibilityIdentifier(ExerciseCardIDs.seatEditIcon(model.id))
    }

    var checkmarkTrailing: some View {
        // The expanded gap moves only the separator left so it aligns with the
        // idle card while the right-anchored checkmark keeps its position.
        HStack(spacing: AppStyle.Layout.inactiveTrailingSeparatorSpacing) {
            Rectangle()
                .fill(AppStyle.Color.idleDivider)
                .frame(width: 0.75, height: 28)
            SharpCheckmark()
                .stroke(AppStyle.Color.idleAccentFill, style: StrokeStyle(lineWidth: 2, lineCap: .square, lineJoin: .miter))
                .frame(width: 14, height: 11)
                .frame(width: AppStyle.Layout.idlePlayButtonSize, height: AppStyle.Layout.idlePlayButtonSize)
        }
        .onTapGesture { isExpanded.toggle() }
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.name)
                .font(theme.titleFont)
                .foregroundColor(theme.titleColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(ExerciseIDs.nameLabel)
                .onTapGesture {
                    if isEditable { onEdit(model.toDomain(), .name) }
                }

            HStack(spacing: 4) {
                Text("Completed exercise")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(theme.subtitleColor)

                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.cardSmallLabel)
                    .foregroundColor(theme.subtitleColor)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Set Tiles

private extension InactiveCardModelView {

    var setTilesRow: some View {
        SetTilesRow(
            setProgress: cachedSetProgress,
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
