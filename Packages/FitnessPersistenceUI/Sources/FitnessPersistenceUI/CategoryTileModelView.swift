import SwiftUI
import SwiftData
import FitnessCore
import FitnessExercise
import FitnessUI
@_spi(PersistenceUI) import FitnessStorage

/// Live-bound spiegel von `CategoryTileView` für Bug 2: die "completed of total"-Anzeige
/// liest direkt aus einem `@Query<ExerciseModel>` mit Predicate auf `(workoutId, category)`.
/// Wenn der Coordinator nach `finish` `model.isCompleted = true` setzt, dispatcht SwiftData
/// das in den Query und die Tile rendert sofort den neuen Count — ohne dass eine parent-View
/// `viewModel.refreshExercises()` aufrufen muss (Bug-2-Quelle).
///
/// Dependency-Boundary (analog T5): die `hasActiveSetForCategory`-Information lebt auf
/// `ActiveSetViewModel` (Session-State, nicht Persistenz) und wird als Plain-Bool von der
/// Parent-View reingereicht. Der `onTap`-Callback ist die Navigation-Boundary.
///
/// **T7-Voraussetzung**: Parent muss `.id(workoutId)` auf der Tile setzen, damit beim
/// Workout-Wechsel das `@Query` mit neuem `workoutId` (re)initialisiert wird (siehe
/// `reviewing-code-changes` SKILL §14d). Der Init-Captured-`workoutId` wird sonst nicht
/// dynamisch aktualisiert.
///
/// **SPI-Marker**: Die View ist `@_spi(PersistenceUI) public`, weil ihre `@Query`-Property
/// `[ExerciseModel]` returnt — und `ExerciseModel` ist nur SPI-sichtbar. Aufrufer (T7)
/// brauchen `@_spi(PersistenceUI) import FitnessPersistenceUI` (konsistent zu ADR-0002 und
/// den 4 Card-Views aus T5).
@_spi(PersistenceUI)
public struct CategoryTileModelView: View {
    public let group: MuscleCategoryGroup
    public let workoutId: UUID
    public let hasActiveSetForCategory: Bool
    public let onTap: () -> Void

    @Query private var exercises: [ExerciseModel]

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

        // Anti-Pattern §14a (Optional-Chain auf der Beziehung) durch denormalisiertes
        // workoutId aus T3 vermieden. Lokale Constants damit der #Predicate die Werte
        // capturen kann, ohne sich auf 'self' zu beziehen.
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
        .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)
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
                    width: CategoryTileViewConstants.CategoryTile.iconSize * 0.9,
                    height: CategoryTileViewConstants.CategoryTile.iconSize * 0.9
                )
                .blur(radius: 15)
                .opacity(0.5)

            Image(group.defaultIconName)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100, alignment: group.iconAlignment)
                .clipped()
                .foregroundColor(AppStyle.Color.white)
        }
        .frame(
            width: CategoryTileViewConstants.CategoryTile.iconSize,
            height: CategoryTileViewConstants.CategoryTile.iconSize
        )
    }

    @ViewBuilder
    private func progressRow(info: ExerciseInfo) -> some View {
        if info.total > 0 {
            HStack(spacing: 8) {
                if !info.isCompleted {
                    ProgressBar(progress: info.progress, totalWidth: 90)
                        .frame(height: CategoryTileViewConstants.ProgressBar.height)
                }

                Spacer()

                Text("\(info.completed) of \(info.total)")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(info.isCompleted ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)
        } else {
            HStack(spacing: 8) {
                Spacer()

                Text(" ")
                    .font(AppStyle.Font.categoryTileProgress)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, CategoryTileViewConstants.CategoryTile.contentPadding)
        }
    }
}

/// Lokal-spiegel der `fileprivate` `ExerciseInfo`-Aggregation aus `CategoryTileView`.
/// Bewusst dupliziert (nicht aus `FitnessExercise` exposed) weil dort `fileprivate`
/// und der Aggregations-Output simpel genug ist. T8 löscht die alte zusammen mit
/// der alten `CategoryTileView`.
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
