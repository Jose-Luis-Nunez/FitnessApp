import SwiftUI
import FitnessAnalytics
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Active card variant rendered against a live `@Bindable ExerciseModel` —
/// read paths go directly through `model.X` without snapshot sync (ADR-0001).
///
/// The edit callback stays `(Exercise, ExerciseEditMode) -> Void`; the
/// `model.toDomain()` call at the boundary is intentional — it only runs
/// when the user actually taps "edit", not on the render path.
///
/// SPI marker: see `ExerciseCardModelView`.
@_spi(PersistenceUI)
public struct ActiveCardModelView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    @Bindable public var model: ExerciseModel
    public let onEdit: (Exercise, ExerciseEditMode) -> Void
    /// Unused by the active variant — the seat stays editable mid-set (gated only
    /// by `model.allowsSeatEditing`); retained for the shared card-init contract
    /// that Idle/Inactive variants still consume.
    public let isEditable: Bool
    public var analyticsViewModel: AnalyticsViewModel

    @State private var isShowingAnalytics = false

    public init(
        model: ExerciseModel,
        onEdit: @escaping (Exercise, ExerciseEditMode) -> Void,
        isEditable: Bool,
        analyticsViewModel: AnalyticsViewModel
    ) {
        self.model = model
        self.onEdit = onEdit
        self.isEditable = isEditable
        self.analyticsViewModel = analyticsViewModel
    }

    private var formattedWeight: String {
        WeightFormatter.displayWeight(model.weight, locale: locale)
    }

    private var iconOverflow: CGFloat { AppStyle.Padding.activeCardIconOverflow }

    public var body: some View {
        ZStack(alignment: .trailing) {
            CardBackground(style: .plain, addPadding: false) {
                cardContentView
                    .padding(.horizontal, AppStyle.Padding.card)
                    .padding(.vertical, 12)
            }

            exerciseIconSection
                .offset(y: -iconOverflow)
                .padding(.trailing, AppStyle.Padding.card)
        }
        .padding(.top, iconOverflow)
        .padding(.horizontal, AppStyle.Padding.card)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: model.toDomain(), viewModel: analyticsViewModel)
        }
    }

    @ViewBuilder
    private var cardContentView: some View {
        let contentView = HStack(alignment: .center, spacing: AppStyle.DeviceLayout.cardSpacing) {
            exerciseChipsSection
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: AppStyle.DeviceLayout.iconContainerWidth + AppStyle.DeviceLayout.analyticsToIconSpacing)
        }
        .frame(height: AppStyle.Layout.activeCardContentHeight)

        if AppStyle.DeviceLayout.isExtraLarge {
            contentView
                .frame(maxWidth: AppStyle.Layout.activeCardMaxWidth)
                .frame(maxWidth: .infinity)
        } else {
            contentView
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var exerciseChipsSection: some View {
        if model.hasWeight {
            HStack(alignment: .bottom, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    setsChip
                    repsChip
                }
                weightChip
                analyticsButton
            }
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(AppStyle.Color.yellow)
                            .font(AppStyle.Font.iconSymbol)
                        Text(verbatim: "\(model.sets)x")
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(AppStyle.Color.white)
                    }
                }

                MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(appColorTheme.accent.primary)
                            .font(AppStyle.Font.iconSymbol)
                        Text(verbatim: "\(model.reps)")
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(AppStyle.Color.white)
                    }
                }

                analyticsButton
            }
        }
    }

    private var setsChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.chipWidthVertical, height: AppStyle.Layout.chipHeight) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(AppStyle.Color.yellow)
                    .font(AppStyle.Font.tileLabel)
                Text(verbatim: "\(model.sets)x")
                    .font(AppStyle.Font.regularChip)
                    .foregroundColor(AppStyle.Color.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var repsChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.chipWidthVertical, height: AppStyle.Layout.chipHeight) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(appColorTheme.accent.primary)
                    .font(AppStyle.Font.tileLabel)
                Text(verbatim: "\(model.reps)")
                    .font(AppStyle.Font.regularChip)
                    .foregroundColor(AppStyle.Color.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var weightChip: some View {
        MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
            Text(formattedWeight)
                .font(AppStyle.Font.regularChip)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        }
    }

    private var analyticsButton: some View {
        Button(action: {
            isShowingAnalytics = true
        }) {
            MetricChipView(width: AppStyle.DeviceLayout.analyticsButtonWidth) {
                Image("analyticsEntry")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: AppStyle.Layout.analyticsImageSize, height: AppStyle.Layout.analyticsImageSize)
                    .foregroundStyle(appColorTheme.accent.trainingAccent)
            }
        }
        .buttonStyle(.plain)
    }

    private var exerciseIconSection: some View {
        ExerciseMuscleIconView(
            iconName: model.displayIconName,
            alignment: model.iconAlignment,
            allowsEditing: model.allowsSeatEditing,
            accessibilityIdentifier: ExerciseCardIDs.seatEditIcon(model.id),
            onEdit: { onEdit(model.toDomain(), .seat) }
        )
    }
}
