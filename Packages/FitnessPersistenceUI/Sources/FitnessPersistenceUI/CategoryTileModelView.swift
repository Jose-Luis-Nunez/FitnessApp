import SwiftUI
import SwiftData
import FitnessCore
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Live-bound mirror of `CategoryTileView` for Bug 2: the "completed of total" display
/// reads directly from a `@Query<ExerciseModel>` with a predicate on `(workoutId, category)`.
/// When the coordinator sets `model.isCompleted = true` after `finish`, SwiftData dispatches
/// that into the query and the tile immediately renders the new count — without a parent view
/// having to call `viewModel.refreshExercises()` (the Bug-2 source).
///
/// Dependency boundary (analogous to T5): the `hasActiveSetForCategory` information lives on
/// `ActiveSetViewModel` (session state, not persistence) and is passed in as a plain Bool by the
/// parent view. The `onTap` callback is the navigation boundary.
///
/// **T7 prerequisite**: the parent must set `.id(workoutId)` on the tile so that on a
/// workout switch the `@Query` is (re)initialized with the new `workoutId` (see
/// `reviewing-code-changes` SKILL §14d). Otherwise the init-captured `workoutId` is not
/// updated dynamically.
///
/// **SPI marker**: The view is `@_spi(PersistenceUI) public`, because its `@Query` property
/// returns `[ExerciseModel]` — and `ExerciseModel` is only SPI-visible. Callers (T7)
/// need `@_spi(PersistenceUI) import FitnessPersistenceUI` (consistent with ADR-0002 and
/// the 4 card views from T5).
@_spi(PersistenceUI)
public struct CategoryTileModelView: View {
    public let group: MuscleCategoryGroup
    public let workoutId: UUID
    public let hasActiveSetForCategory: Bool
    public let onTap: () -> Void

    @Query private var exercises: [ExerciseModel]
    @Environment(\.appColorTheme) private var appColorTheme

    public init(
        group: MuscleCategoryGroup,
        workoutId: UUID,
        hasActiveSetForCategory: Bool,
        onTap: @escaping () -> Void
    ) {
        self.group = group
        self.workoutId = workoutId
        self.hasActiveSetForCategory = hasActiveSetForCategory
        self.onTap = onTap

        // Anti-pattern §14a (optional chain on the relationship) avoided via the
        // denormalized workoutId from T3. Local constants so the #Predicate can capture
        // the values without referring to 'self'.
        let raw = group.rawValue
        let wid = workoutId
        _exercises = Query(
            filter: #Predicate<ExerciseModel> { exercise in
                exercise.workoutId == wid && exercise.category == raw
            }
        )
    }

    public var body: some View {
        // Deactivated exercises keep their data but drop out of the progress
        // counts: a 4/5 category becomes 4/4 when its open 5th exercise is
        // deactivated. `isActive == nil` (pre-migration rows) counts as active.
        let activeExercises = exercises.filter { $0.isActive ?? true }
        let info = ExerciseInfo(
            total: activeExercises.count,
            active: activeExercises.lazy.filter { !$0.isCompleted }.count,
            hasActiveSet: hasActiveSetForCategory
        )

        Button(action: onTap) {
            tileContent(info: info)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileContent(info: ExerciseInfo) -> some View {
        CardBackground(
            backgroundColor: AppStyle.Color.exerciseCardBackground,
            useGlassEffect: true,
            addPadding: false
        ) {
            VStack(spacing: ExerciseCardLayout.CategoryTile.contentSpacing) {
                headerRow(info: info)
                iconView
                Spacer().frame(height: ExerciseCardLayout.CategoryTile.footerSpacerHeight)
                progressRow(info: info)
            }
            .padding(.vertical, ExerciseCardLayout.CategoryTile.verticalPadding)
            .overlay(
                info.isCompleted
                    ? RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .fill(appColorTheme.accent.primary.opacity(AppStyle.Opacity.categoryTileCompletionOverlay))
                    : nil
            )
        }
        .frame(height: ExerciseCardLayout.CategoryTile.height)
    }

    private func headerRow(info: ExerciseInfo) -> some View {
        HStack {
            Text(group.displayName)
                .font(AppStyle.Font.categoryTileTitle)
                .foregroundColor(info.isCompleted ? appColorTheme.accent.glow : AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            headerBadge(info: info)
        }
        .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
    }

    @ViewBuilder
    private func headerBadge(info: ExerciseInfo) -> some View {
        if info.isCompleted {
            ZStack {
                Circle()
                    .fill(appColorTheme.accent.glow)
                    .frame(
                        width: ExerciseCardLayout.CategoryTile.headerBadgeSize,
                        height: ExerciseCardLayout.CategoryTile.headerBadgeSize
                    )

                Image(systemName: "checkmark")
                    .font(AppStyle.Font.categoryTileCount)
                    .foregroundColor(AppStyle.Color.exerciseCardBackground)
            }
        } else if info.total == 0 {
            ZStack {
                Circle()
                    .fill(appColorTheme.accent.glow)
                    .frame(
                        width: ExerciseCardLayout.CategoryTile.headerBadgeSize,
                        height: ExerciseCardLayout.CategoryTile.headerBadgeSize
                    )

                Image(systemName: "plus")
                    .font(AppStyle.Font.categoryTileBadge)
                    .foregroundColor(appColorTheme.accent.black)
            }
        } else {
            Spacer().frame(
                width: ExerciseCardLayout.CategoryTile.headerBadgeSize,
                height: ExerciseCardLayout.CategoryTile.headerBadgeSize
            )
        }
    }

    private var iconView: some View {
        CategoryTileArtworkStage(alignment: group.iconAlignment) {
            Image(appColorTheme.scheme.iconName(for: group.defaultIconName))
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .foregroundColor(AppStyle.Color.white)
        }
    }

    @ViewBuilder
    private func progressRow(info: ExerciseInfo) -> some View {
        if info.total > 0 {
            HStack(spacing: ExerciseCardLayout.CategoryTile.contentSpacing) {
                if !info.isCompleted {
                    ProgressBar(
                        progress: info.progress,
                        totalWidth: ExerciseCardLayout.CategoryTile.progressWidth
                    )
                        .frame(height: ExerciseCardLayout.ProgressBar.height)
                }

                Spacer()

                Text("\(info.completed) of \(info.total)")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(info.isCompleted ? appColorTheme.accent.glow : AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(ExerciseCardLayout.CategoryTile.minimumTextScale)
            }
            .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
        } else {
            HStack(spacing: ExerciseCardLayout.CategoryTile.contentSpacing) {
                Spacer()

                Text(" ")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
        }
    }
}

/// View-local aggregation for category progress and completion state.
private struct ExerciseInfo {
    let total: Int
    let completed: Int
    let isCompleted: Bool
    let progress: Double

    init(total: Int, active: Int, hasActiveSet: Bool) {
        self.total = total
        self.completed = max(0, total - active)
        self.isCompleted = (active == 0 && total > 0 && !hasActiveSet)
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
    }
}
