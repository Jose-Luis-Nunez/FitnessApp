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
    @AppStorage(DefaultIconColorScheme.storageKey) private var iconColorScheme: DefaultIconColorScheme = .green

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
        let info = ExerciseInfo(
            total: exercises.count,
            active: exercises.lazy.filter { !$0.isCompleted }.count,
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
            VStack(spacing: 8) {
                headerRow(info: info)
                iconView
                Spacer().frame(height: 3)
                progressRow(info: info)
            }
            .padding(.vertical, 12)
            .overlay(
                info.isCompleted
                    ? RoundedRectangle(cornerRadius: 16).fill(AppStyle.Color.green.opacity(0.3))
                    : nil
            )
        }
    }

    private func headerRow(info: ExerciseInfo) -> some View {
        HStack {
            Text(group.displayName)
                .font(AppStyle.Font.categoryTileTitle)
                .foregroundColor(info.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
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
                    .fill(AppStyle.Color.greenGlow)
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(AppStyle.Font.categoryTileCount)
                    .foregroundColor(AppStyle.Color.exerciseCardBackground)
            }
        } else if info.total == 0 {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.greenGlow)
                    .frame(width: 32, height: 32)

                Image(systemName: "plus")
                    .font(AppStyle.Font.categoryTileBadge)
                    .foregroundColor(AppStyle.Color.greenBlack)
            }
        } else {
            Spacer().frame(width: 32, height: 32)
        }
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.greenBlack)
                .frame(
                    width: ExerciseCardLayout.CategoryTile.iconSize * 0.9,
                    height: ExerciseCardLayout.CategoryTile.iconSize * 0.9
                )
                .blur(radius: 15)
                .opacity(0.5)

            Image(iconColorScheme.iconName(for: group.defaultIconName))
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100, alignment: group.iconAlignment)
                .clipped()
                .foregroundColor(AppStyle.Color.white)
        }
        .frame(
            width: ExerciseCardLayout.CategoryTile.iconSize,
            height: ExerciseCardLayout.CategoryTile.iconSize
        )
    }

    @ViewBuilder
    private func progressRow(info: ExerciseInfo) -> some View {
        if info.total > 0 {
            HStack(spacing: 8) {
                if !info.isCompleted {
                    ProgressBar(progress: info.progress, totalWidth: 90)
                        .frame(height: ExerciseCardLayout.ProgressBar.height)
                }

                Spacer()

                Text("\(info.completed) of \(info.total)")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(info.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
        } else {
            HStack(spacing: 8) {
                Spacer()

                Text(" ")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, ExerciseCardLayout.CategoryTile.contentPadding)
        }
    }
}

/// Local mirror of the `fileprivate` `ExerciseInfo` aggregation from `CategoryTileView`.
/// Intentionally duplicated (not exposed from `FitnessExercise`) because it is `fileprivate`
/// there and the aggregation output is simple enough. T8 deletes the old one together with
/// the old `CategoryTileView`.
private struct ExerciseInfo {
    let total: Int
    let active: Int
    let completed: Int
    let isCompleted: Bool
    let progress: Double
    let hasActiveSet: Bool

    init(total: Int, active: Int, hasActiveSet: Bool) {
        self.total = total
        self.active = active
        self.completed = max(0, total - active)
        self.isCompleted = (active == 0 && total > 0 && !hasActiveSet)
        self.progress = total > 0 ? Double(completed) / Double(total) : 0.0
        self.hasActiveSet = hasActiveSet
    }
}
