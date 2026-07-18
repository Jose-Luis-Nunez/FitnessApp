import SwiftUI
import FitnessCore
import FitnessUI

public enum WorkoutTileLayout {
    case compact
    case hero
}

enum WorkoutTileArtwork {
    static let assetName = "workoutDefaultIcon"
}

public struct WorkoutTileView: View {
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

                        Text(workout.name)
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
                        ? AppStyle.Color.green.opacity(AppStyle.Opacity.workoutTileCompactDefaultFill)
                        : AppStyle.Color.exerciseCardBackground,
                    in: RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton, style: .continuous)
                )
                .overlay {
                    if isDefault {
                        RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton, style: .continuous)
                            .stroke(
                                AppStyle.Color.green,
                                lineWidth: AppStyle.Layout.workoutTileCompactBorderWidth
                            )
                    }
                }
            )

            settingsButton(iconSize: AppStyle.Layout.workoutTileCompactSettingsIconSize)
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
                                AppStyle.Color.green.opacity(AppStyle.Opacity.workoutHeroBorder),
                                lineWidth: AppStyle.Layout.workoutHeroBorderWidth
                            )
                    }
                }
            )

            settingsButton(iconSize: AppStyle.Layout.workoutHeroSettingsIconSize)
                .padding(.top, heroSettingsTopInset)
                .padding(.trailing, heroSettingsTrailingInset)
        }
    }

    private var heroArtwork: some View {
        CategoryTileArtworkStage(
            alignment: workout.type.iconAlignment
        ) {
            Image(WorkoutTileArtwork.assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        }
        .allowsHitTesting(false)
    }

    private var heroContent: some View {
        VStack(spacing: ExerciseCardLayout.CategoryTile.contentSpacing) {
            HStack {
                Text(workout.name)
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

            ZStack {
                heroArtwork

                HStack {
                    heroCountBadge
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ExerciseCardLayout.CategoryTile.iconSize)
            .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)

            Spacer().frame(height: ExerciseCardLayout.CategoryTile.footerSpacerHeight)

            heroFooter
        }
        .padding(.vertical, ExerciseCardLayout.CategoryTile.verticalPadding)
    }

    private var heroFooter: some View {
        HStack(spacing: ExerciseCardLayout.CategoryTile.contentSpacing) {
            Spacer(minLength: 0)

            Text(" ")
                .font(AppStyle.Font.categoryTileProgress)
                .foregroundColor(.clear)
        }
        .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
        .overlay(alignment: .trailing) {
            startChip
                .padding(.trailing, ExerciseCardLayout.CategoryTile.contentPadding)
        }
    }

    private var startChip: some View {
        Text("Start")
            .font(AppStyle.Font.categoryTileProgress)
            .foregroundColor(AppStyle.Color.green)
            .padding(.horizontal, AppStyle.Layout.workoutHeroStartChipHorizontalPadding)
            .padding(.vertical, AppStyle.Layout.workoutHeroStartChipVerticalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(AppStyle.Color.backgroundColor.opacity(AppStyle.Opacity.workoutHeroStartChipFill))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        AppStyle.Color.green,
                        lineWidth: AppStyle.Layout.workoutHeroStartChipBorderWidth
                    )
            }
            .fixedSize()
    }

    private var heroSettingsInsetAdjustment: CGFloat {
        (AppStyle.Layout.minimumTapTargetSize - ExerciseCardLayout.CategoryTile.headerBadgeSize) / 2
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
                .stroke(isDefault ? AppStyle.Color.green : AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel), lineWidth: AppStyle.Layout.workoutTileCompactCountOuterStroke)
                .frame(width: AppStyle.Layout.workoutTileCompactCountOuterSize, height: AppStyle.Layout.workoutTileCompactCountOuterSize)
            Circle()
                .stroke(isDefault ? AppStyle.Color.green.opacity(AppStyle.Opacity.fadedOverlay) : AppStyle.Color.white.opacity(AppStyle.Opacity.disabledElement), lineWidth: AppStyle.Layout.workoutTileCompactCountInnerStroke)
                .frame(width: AppStyle.Layout.workoutTileCompactCountInnerSize, height: AppStyle.Layout.workoutTileCompactCountInnerSize)
            Text("\(exerciseCount)")
                .font(AppStyle.Font.detailBadge)
                .foregroundColor(isDefault ? AppStyle.Color.green : AppStyle.Color.white)
        }
    }

    private var heroCountBadge: some View {
        ZStack {
            Circle()
                .stroke(AppStyle.Color.green, lineWidth: AppStyle.Layout.workoutHeroCountOuterStroke)
                .frame(
                    width: ExerciseCardLayout.CategoryTile.headerBadgeSize,
                    height: ExerciseCardLayout.CategoryTile.headerBadgeSize
                )
            Circle()
                .stroke(AppStyle.Color.green.opacity(AppStyle.Opacity.fadedOverlay), lineWidth: AppStyle.Layout.workoutHeroCountInnerStroke)
                .frame(
                    width: ExerciseCardLayout.CategoryTile.headerBadgeInnerSize,
                    height: ExerciseCardLayout.CategoryTile.headerBadgeInnerSize
                )
            Text("\(exerciseCount)")
                .font(AppStyle.Font.categoryTileCount)
                .foregroundColor(AppStyle.Color.green)
                .lineLimit(1)
                .minimumScaleFactor(AppStyle.Layout.workoutHeroCountMinimumScale)
                .frame(width: ExerciseCardLayout.CategoryTile.headerBadgeInnerSize)
        }
    }

    @ViewBuilder
    private func settingsButton(iconSize: CGFloat) -> some View {
        if let onSettingsTap {
            Button(action: onSettingsTap) {
                Image("settingsIconMenu")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                    .frame(
                        minWidth: AppStyle.Layout.minimumTapTargetSize,
                        minHeight: AppStyle.Layout.minimumTapTargetSize
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings for \(workout.name)")
            .accessibilityIdentifier(settingsAccessibilityIdentifier)
        }
    }

    private var exerciseCountLabel: String {
        "\(exerciseCount) \(exerciseCount == 1 ? "Übung" : "Übungen")"
    }

    private var tileAccessibilityIdentifier: String {
        WorkoutIDs.tile(workout.id)
    }

    private var settingsAccessibilityIdentifier: String {
        WorkoutIDs.settings(workout.id)
    }

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
