import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Completed (inactive) card variant rendered against a live
/// `@Bindable ExerciseModel`. Datenquelle ist die SwiftData-`@Model`-Instanz —
/// alle Edits propagieren automatisch ohne Snapshot-Sync (ADR-0001). Behält
/// noch das `analyticsViewModel.changeCount`-Polling-Pattern; das wird in
/// einem späteren Schritt zugunsten direkten `@Observable`-Trackings aufgelöst.
///
/// SPI-Marker: siehe `ExerciseCardModelView`.
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

    public var body: some View {
        CardShell(theme: .completed, edgeIndicator: .completed, leading: {
            categoryIconView
        }, trailing: {
            checkmarkIcon
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
        Image(model.displayIconName)
            .resizable()
            .scaledToFill()
            .frame(width: AppStyle.Layout.categoryIconSize, height: AppStyle.Layout.categoryIconSize, alignment: model.iconAlignment)
            .clipped()
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
                .accessibilityIdentifier(ExerciseIDs.nameLabel)
                .onTapGesture {
                    if isEditable { onEdit(model.toDomain(), .name) }
                }

            HStack(spacing: 4) {
                Text("Completed workout")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(.white.opacity(0.7))

                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.cardSmallLabel)
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var checkmarkIcon: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)

            Image(systemName: "checkmark")
                .font(AppStyle.Font.categoryTileCount)
                .foregroundColor(AppStyle.Color.exerciseCardBackground)
        }
        .onTapGesture { isExpanded.toggle() }
    }
}

// MARK: - Set Tiles

private extension InactiveCardModelView {

    var setTilesRow: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = cachedSetProgress.count > 3
            let scrollChevronWidth: CGFloat = 8
            let chevronArea: CGFloat = hasMoreThan3 ? scrollChevronWidth + spacing : 0
            let resetTotal: CGFloat = isResetEnabled ? ExerciseCardLayout.ResetButton.size + spacing : 0
            let scrollAreaWidth = geo.size.width - resetTotal - chevronArea
            let tileWidth = (scrollAreaWidth - spacing * 2) / 3

            HStack(spacing: spacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(cachedSetProgress.enumerated()), id: \.element.id) { index, item in
                            SetTileView(setNumber: index + 1, weight: item.weight, reps: item.currentReps, hasWeight: model.hasWeight)
                                .frame(width: tileWidth)
                        }
                    }
                }
                .frame(width: scrollAreaWidth)
                .onTapGesture { isShowingAnalytics = true }

                if hasMoreThan3 {
                    Image(systemName: "chevron.compact.right")
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: scrollChevronWidth)
                }

                if isResetEnabled {
                    ExerciseCardResetButton { onReset?(model.toDomain()) }
                }
            }
        }
    }
}
