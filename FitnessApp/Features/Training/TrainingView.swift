import SwiftUI
import SwiftData
import FitnessCore
import FitnessUI
import FitnessExercise
import FitnessAnalytics
import FitnessTraining
@_spi(PersistenceUI) import FitnessStorage
@_spi(PersistenceUI) import FitnessPersistenceUI
import Factory

/// Hosts the active training session for a single exercise.
///
/// Architecture note (ADR-0001 / T8d): the screen is parameterised by an
/// `exerciseId`, not an `Exercise` value. The id is resolved to a live
/// `ExerciseModel` via `@Query`, so any subsequent mutation (rename, weight
/// edit, completion flag flip) propagates into the card automatically — the
/// snapshot-sync via the legacy `ExerciseCardViewModel` is gone.
///
/// Coordinator APIs (`TrainingCoordinator.startTraining(for:)`,
/// `TrainingActionBarComponent`) still operate on `Exercise` (DTO), so we
/// bridge with `model.toDomain()` at the call sites.
struct TrainingView: View {
    let exerciseId: UUID
    let category: MuscleCategoryGroup

    @Environment(AppRouter.self) private var router
    private var trainingCoordinator: TrainingCoordinator
    @State private var analyticsViewModel: AnalyticsViewModel
    @Environment(UIOverlayState.self) private var overlayState

    @Query private var models: [ExerciseModel]
    @State private var phase: Phase = .waitingForQuery

    /// Drives the reused "Edit Seat" overlay (`ExerciseSeatPickerView`) when the
    /// user taps the exercise body icon during an active session. Seat editing
    /// was previously unreachable here — the card's `onEdit` was a no-op — which
    /// is the "Sitz verstellen geht nicht / nicht sichtbar" feedback.
    @State private var formViewModel = ExerciseFormViewModel()

    private enum Phase {
        case waitingForQuery
        case active
        case finishing
        case cancelling
        case navigatedBack
    }

    init(exerciseId: UUID, category: MuscleCategoryGroup) {
        self.exerciseId = exerciseId
        self.category = category

        // Predicate filters by id; the result is at most one model. We can't
        // use `.first` directly inside `#Predicate`, so we evaluate `models.first`
        // in the body. Capturing the id in the predicate as a local prevents a
        // recapture warning if `exerciseId` is mutated later (it isn't here, but
        // SwiftData's macro expansion is sensitive to the closure's capture set).
        let id = exerciseId
        self._models = Query(filter: #Predicate<ExerciseModel> { $0.id == id })

        let coordinatorCache = Container.shared.trainingCoordinatorCache()
        let coordinator = coordinatorCache.coordinator(for: category)
        self.trainingCoordinator = coordinator

        self._analyticsViewModel = State(wrappedValue: coordinator.analyticsViewModel)
    }

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaBottomInset: CGFloat { safeAreaInsets.bottom }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: trainingCoordinator.isTrainingActive)

            // The `@Query` result is empty until SwiftData materialises the row.
            // In practice this is synchronous on a hot store, but keep the
            // unwrap explicit so the view doesn't crash on a deep-link / cold
            // launch into a deleted id.
            if let model = models.first, trainingCoordinator.isTrainingActive {
                trainingContent(model: model)
            }

            // Training Mini Menu Overlay
            if overlayState.showTrainingMiniMenu {
                miniMenuOverlay
            }

            // Reused "Edit Seat" overlay — same component as the idle/category flow.
            if formViewModel.showForm {
                Color.clear.onAppear { overlayState.isEditingSheetVisible = true }
                ExerciseSeatPickerView(
                    formViewModel: formViewModel,
                    isPresented: $formViewModel.showForm,
                    onSave: { saveSeat() },
                    onCancel: { formViewModel.clearForm() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .shadow(radius: 5)
                .transition(.identity)
                .zIndex(3)
                .onDisappear { overlayState.isEditingSheetVisible = false }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            startTrainingIfReady()
        }
        .onChange(of: models.first?.id) { _, _ in
            startTrainingIfReady()
        }
        .onChange(of: trainingCoordinator.isTrainingActive) { _, isActive in
            if !isActive && phase == .active {
                phase = .finishing
                overlayState.showTrainingMiniMenu = false

                Task { @MainActor in
                    try? await Task.sleep(for: TimingConstants.popDelayAfterFinish)
                    router.pop()
                }
            } else if !isActive && phase == .cancelling {
                overlayState.showTrainingMiniMenu = false
            }
        }
        .onDisappear {
            phase = .navigatedBack
            overlayState.showTrainingMiniMenu = false
        }
    }

    @ViewBuilder
    private func trainingContent(model: ExerciseModel) -> some View {
        VStack(spacing: 0) {
            Text(model.name)
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, AppStyle.Padding.titleTop)
                .padding(.bottom, AppStyle.Padding.titleBottomBeforeActiveCard)

            ScrollView {
                LazyVStack(spacing: 16) {
                    ExerciseCardModelView(
                        model: model,
                        onEdit: { exercise, mode in
                            guard mode == .seat else { return }
                            withAnimation {
                                formViewModel.loadExercise(exercise, category: category)
                                formViewModel.editMode = .seat
                                formViewModel.showForm = true
                            }
                        },
                        isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                        analyticsViewModel: analyticsViewModel,
                        activeSetViewModel: trainingCoordinator.activeSetViewModel,
                        onStart: { _ in
                            // Exercise is already started when view appears
                        },
                        onReset: { _ in
                            trainingCoordinator.resetExercise()
                        },
                        isActiveSetVisible: trainingCoordinator.isTrainingActive,
                        isResetEnabled: model.isCompleted
                    )

                    TrainingSessionComponent(
                        coordinator: trainingCoordinator,
                        onCancel: { cancelTraining() },
                        analyticsViewModel: analyticsViewModel
                    )
                }
                .padding(.horizontal, 0)
                .padding(.bottom, safeAreaBottomInset + 120) // Space for FABs
            }
        }

        TrainingActionBarComponent(
            coordinator: trainingCoordinator,
            exercises: [model.toDomain()],
            hasActiveExercise: trainingCoordinator.isTrainingActive
        )
        .padding(.bottom, safeAreaBottomInset + 12)

        TrainingPickerComponent(coordinator: trainingCoordinator)

        FeedbackSheetComponent(
            coordinator: trainingCoordinator,
            category: category
        )
    }

    private var miniMenuOverlay: some View {
        Group {
            Color.black.opacity(0.001)
                .ignoresSafeArea(.all)
                .onTapGesture { overlayState.showTrainingMiniMenu = false }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MiniActionMenuView(
                        title: nil,
                        items: [
                            MiniActionMenuItem(
                                icon: "xmark",
                                title: "Cancel",
                                isDestructive: true
                            ) {
                                cancelTraining()
                            }
                        ],
                        width: min(UIScreen.main.bounds.width * 0.55, 320),
                        minHeight: 140
                    )
                    .padding(.trailing, 12)
                }
                .padding(.bottom, safeAreaBottomInset - 50)
            }
            .transition(.opacity)
            .zIndex(4)
        }
    }

    private enum TimingConstants {
        /// Lets the `isTrainingActive` `.easeInOut(duration: 0.2)` exit
        /// animation play to completion before the navigation pops; without
        /// this the user sees a frame of un-animated empty screen.
        static let popDelayAfterFinish: Duration = .milliseconds(100)

        /// Holds the `isCancellingTraining` overlay flag for the duration of
        /// the `router.replaceAll(with:)` transition so the mini-menu doesn't
        /// flicker back into view on the intermediate stack frame.
        static let cancelOverlayHoldDuration: Duration = .milliseconds(200)
    }

    private func startTrainingIfReady() {
        guard phase == .waitingForQuery, let model = models.first else { return }
        phase = .active
        trainingCoordinator.startTraining(for: model.toDomain())
    }

    /// Persists the edited seat through the coordinator, which routes it via the
    /// app's single exercise-write path (storage service). The view must NOT
    /// mutate the `@Model` directly: that conflicts with the storage service's
    /// separate `ModelContext` (full delete+reinsert) and leaves phantom cards in
    /// the category `@Query`. See `TrainingCoordinator.updateActiveSeat`.
    private func saveSeat() {
        let trimmed = formViewModel.seat.trimmingCharacters(in: .whitespaces)
        let newSeat: String? = trimmed.isEmpty ? nil : trimmed
        trainingCoordinator.updateActiveSeat(newSeat)
        formViewModel.clearForm()
    }

    private func cancelTraining() {
        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? category
        phase = .cancelling
        overlayState.isCancellingTraining = true
        overlayState.showTrainingMiniMenu = false

        trainingCoordinator.cancelTraining()
        router.replaceAll(with: [.home, .muscleCategory(targetCategory)])

        Task { @MainActor in
            try? await Task.sleep(for: TimingConstants.cancelOverlayHoldDuration)
            overlayState.isCancellingTraining = false
        }
    }

    #Preview {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: WorkoutModel.self, ExerciseModel.self,
            configurations: config
        )
        let context = ModelContext(container)
        let workoutId = UUID()
        let workout = WorkoutModel(
            id: workoutId,
            name: "Preview Workout",
            selectedCategories: [MuscleCategoryGroup.chest.rawValue],
            createdDate: .now,
            lastModified: .now
        )
        context.insert(workout)

        let model = ExerciseModel(
            id: UUID(),
            workoutId: workoutId,
            name: "Sample Exercise",
            weight: 20.0,
            reps: 12,
            sets: 3,
            iconName: "defaultChestIcon",
            category: MuscleCategoryGroup.chest.rawValue,
            workout: workout
        )
        context.insert(model)
        try? context.save()

        return NavigationStack {
            TrainingView(exerciseId: model.id, category: .chest)
        }
        .environment(UIOverlayState())
        .environment(AppRouter())
        .modelContainer(container)
    }
}
