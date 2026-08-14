import SwiftUI
import FitnessCore
import FitnessUI
import FitnessResources

public enum WorkoutTileLayout {
    case compact
    case hero
}

enum WorkoutTileArtwork {
    static let assetName = "workoutDefaultIcon"

    /// Overview tiles use one fixed upper-body composition for every workout type.
    static func heroCropAlignment(for workoutType: WorkoutType) -> Alignment {
        switch workoutType {
        case .pull, .push, .leg, .individual, .full:
            return .top
        }
    }
}

public struct WorkoutTileView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let workout: Workout
    let isDefault: Bool
    let exerciseCount: Int
    let onTap: () -> Void
    let layout: WorkoutTileLayout
    var onLongPress: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil

    public init(
        workout: Workout,
        isDefault: Bool,
        exerciseCount: Int,
        onTap: @escaping () -> Void,
        layout: WorkoutTileLayout = .compact,
        onLongPress: (() -> Void)? = nil,
        onSettingsTap: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.isDefault = isDefault
        self.exerciseCount = exerciseCount
        self.onTap = onTap
        self.layout = layout
        self.onLongPress = onLongPress
        self.onSettingsTap = onSettingsTap
    }

    public var body: some View {
        Group {
            switch layout {
            case .compact:
                compactTile
            case .hero:
                heroTile
            }
        }
    }

    private var compactTile: some View {
        ZStack(alignment: .topTrailing) {
            interactiveTile(
                ZStack(alignment: .topLeading) {
                    VStack {
                        Spacer()

                        Text(verbatim: workout.name)
                            .font(AppStyle.Font.categorySelectionNameFont)
                            .foregroundColor(AppStyle.Color.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(AppStyle.Padding.card)

                    compactCountBadge
                        .padding(.leading, AppStyle.Layout.workoutTileCompactCountInset)
                        .padding(.top, AppStyle.Layout.workoutTileCompactCountInset)
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppStyle.Layout.workoutTileCompactHeight)
                .appDarkSurface(
                    backgroundColor: isDefault
                        ? appColorTheme.accent.primary.opacity(AppStyle.Opacity.workoutTileCompactDefaultFill)
                        : AppStyle.Color.exerciseCardBackground,
                    in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton, style: .continuous)
                )
                .overlay {
                    if isDefault {
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton, style: .continuous)
                            .stroke(
                                appColorTheme.accent.primary,
                                lineWidth: AppStyle.Layout.workoutTileCompactBorderWidth
                            )
                    }
                }
            )

            settingsButton(
                iconSize: AppStyle.Layout.workoutTileCompactSettingsIconSize,
                tapTargetSize: AppStyle.Layout.minimumTapTargetSize
            )
                .padding(.top, AppStyle.Layout.workoutTileCompactSettingsTopInset)
                .padding(.trailing, AppStyle.Padding.card)
        }
    }

    private var heroTile: some View {
        ZStack(alignment: .topTrailing) {
            interactiveTile(
                CardBackground(
                    backgroundColor: AppStyle.Color.exerciseCardBackground,
                    useGlassEffect: true,
                    addPadding: false
                ) {
                    heroContent
                }
                .frame(maxWidth: .infinity)
                .frame(height: ExerciseCardLayout.CategoryTile.height)
                .overlay {
                    if isDefault {
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card, style: .continuous)
                            .stroke(
                                appColorTheme.accent.primary.opacity(AppStyle.Opacity.workoutHeroBorder),
                                lineWidth: AppStyle.Layout.workoutHeroBorderWidth
                            )
                    }
                }
            )

            settingsButton(
                iconSize: AppStyle.Layout.workoutHeroSettingsIconSize,
                tapTargetSize: Self.heroSettingsTapTargetSize
            )
                .padding(.top, heroSettingsTopInset)
                .padding(.trailing, heroSettingsTrailingInset)
        }
    }

    private var heroArtwork: some View {
        Image(WorkoutTileArtwork.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(
                width: AppStyle.Layout.workoutHeroArtworkWidth,
                height: AppStyle.Layout.workoutHeroArtworkHeight,
                alignment: WorkoutTileArtwork.heroCropAlignment(for: workout.type)
            )
            .clipped()
            .offset(x: AppStyle.Layout.workoutHeroArtworkTrailingOverflow)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomTrailing
            )
            .clipped()
            .allowsHitTesting(false)
    }

    private var heroContent: some View {
        ZStack {
            heroArtwork

            VStack(spacing: 0) {
                heroHeader

                Spacer()
                    .frame(height: AppStyle.Layout.workoutHeroMetricsTopSpacing)

                heroExerciseCount

                Spacer(minLength: 0)

                HStack {
                    startChip
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
            }
            .padding(.vertical, ExerciseCardLayout.CategoryTile.verticalPadding)
        }
    }

    private var heroHeader: some View {
        HStack {
            Text(verbatim: workout.name)
                .font(AppStyle.Font.categoryTileTitle)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(ExerciseCardLayout.CategoryTile.minimumTextScale)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Color.clear
                .frame(
                    width: ExerciseCardLayout.CategoryTile.headerBadgeSize,
                    height: ExerciseCardLayout.CategoryTile.headerBadgeSize
                )
        }
        .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
    }

    private var heroExerciseCount: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(exerciseCount)")
                .font(AppStyle.Font.workoutHeroExerciseCount)
                .foregroundColor(appColorTheme.accent.primary)
                .lineLimit(1)

            Text(exerciseCount == 1 ? AppText.exerciseSingular : AppText.exercisePlural)
                .font(AppStyle.Font.workoutHeroExerciseLabel)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
    }

    private var startChip: some View {
        HStack(spacing: AppStyle.Layout.workoutHeroStartChipIconSpacing) {
            Text(AppText.actionStart)
                .font(AppStyle.Font.categoryTileProgress)

            Image(systemName: "chevron.right")
                .font(AppStyle.Font.categoryTileProgress)
        }
        .foregroundColor(appColorTheme.accent.primary)
        .padding(.horizontal, AppStyle.Layout.workoutHeroStartChipHorizontalPadding)
        .padding(.vertical, AppStyle.Layout.workoutHeroStartChipVerticalPadding)
        .overlay {
            RoundedRectangle(
                cornerRadius: AppStyle.CornerRadius.workoutHeroStartChip,
                style: .continuous
            )
            .stroke(
                appColorTheme.accent.primary,
                lineWidth: AppStyle.Layout.workoutHeroStartChipBorderWidth
            )
        }
        .fixedSize()
    }

    private var heroSettingsInsetAdjustment: CGFloat {
        (Self.heroSettingsTapTargetSize - ExerciseCardLayout.CategoryTile.headerBadgeSize) / 2
    }

    private var heroSettingsTopInset: CGFloat {
        ExerciseCardLayout.CategoryTile.verticalPadding - heroSettingsInsetAdjustment
    }

    private var heroSettingsTrailingInset: CGFloat {
        ExerciseCardLayout.CategoryTile.contentPadding - heroSettingsInsetAdjustment
    }

    private var compactCountBadge: some View {
        ZStack {
            Circle()
                .stroke(isDefault ? appColorTheme.accent.primary : AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel), lineWidth: AppStyle.Layout.workoutTileCompactCountOuterStroke)
                .frame(width: AppStyle.Layout.workoutTileCompactCountOuterSize, height: AppStyle.Layout.workoutTileCompactCountOuterSize)
            Circle()
                .stroke(isDefault ? appColorTheme.accent.primary.opacity(AppStyle.Opacity.fadedOverlay) : AppStyle.Color.white.opacity(AppStyle.Opacity.disabledElement), lineWidth: AppStyle.Layout.workoutTileCompactCountInnerStroke)
                .frame(width: AppStyle.Layout.workoutTileCompactCountInnerSize, height: AppStyle.Layout.workoutTileCompactCountInnerSize)
            Text(verbatim: "\(exerciseCount)")
                .font(AppStyle.Font.detailBadge)
                .foregroundColor(isDefault ? appColorTheme.accent.primary : AppStyle.Color.white)
        }
    }

    @ViewBuilder
    private func settingsButton(
        iconSize: CGFloat,
        tapTargetSize: CGFloat
    ) -> some View {
        if let onSettingsTap {
            Button(action: onSettingsTap) {
                Image("settingsIconMenu")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                    .frame(
                        width: tapTargetSize,
                        height: tapTargetSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zIndex(1)
            .accessibilityLabel(AppText.workoutSettingsAccessibility(name: workout.name))
            .accessibilityIdentifier(settingsAccessibilityIdentifier)
        }
    }

    private var exerciseCountLabel: LocalizedStringResource {
        AppText.exerciseCount(count: exerciseCount)
    }

    private var tileAccessibilityIdentifier: String {
        WorkoutIDs.tile(workout.id)
    }

    private var settingsAccessibilityIdentifier: String {
        WorkoutIDs.settings(workout.id)
    }

    private static let heroSettingsTapTargetSize: CGFloat = 60

    private func interactiveTile<Content: View>(_ content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(workout.name)
            .accessibilityValue(exerciseCountLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(tileAccessibilityIdentifier)
            .accessibilityAction { onTap() }
            .gesture(tileInteractionGesture)
    }

    private var tileInteractionGesture: some Gesture {
        LongPressGesture()
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first(true):
                    onLongPress?()
                case .second:
                    onTap()
                case .first(false):
                    break
                }
            }
    }
}
