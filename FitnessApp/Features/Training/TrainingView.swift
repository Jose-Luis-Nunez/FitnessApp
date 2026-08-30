import SwiftUI
import SwiftData
import FitnessCore
import FitnessResources
import FitnessUI
import FitnessExercise
import FitnessTraining
@_spi(PersistenceUI) import FitnessStorage
import Factory

/// Presents one live training session above the current category/list screen.
///
/// The presentation carries only an exercise id and category. This app-layer
/// host resolves the live SwiftData model through `@Query`, then bridges to the
/// DTO-based `TrainingCoordinator` at the existing package boundary. Hiding
/// the sheet never owns or clears the coordinator session.
struct TrainingSheetView: View {
    let exerciseId: UUID
    let category: MuscleCategoryGroup

    @Environment(AppRouter.self) private var router
    @Environment(UIOverlayState.self) private var overlayState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    private var trainingCoordinator: TrainingCoordinator
    @Query private var models: [ExerciseModel]
    @State private var phase: Phase = .waitingForQuery
    @State private var formViewModel = ExerciseFormViewModel()
    @State private var sheetHeightLatch = TrainingSheetHeightLatch()
    /// Tracks the pull-down while the finger is still down, so the sheet follows
    /// it. Without this the gesture only fired on release and the sheet sat
    /// perfectly still while being dragged — no sense of how far the pull still
    /// had to go, and nothing at all below the threshold. `@GestureState` resets
    /// itself on release, which is what springs the sheet back.
    @GestureState private var dragTranslation: CGFloat = 0

    private enum Phase {
        case waitingForQuery
        case active
        case finishing
    }

    init(exerciseId: UUID, category: MuscleCategoryGroup) {
        self.exerciseId = exerciseId
        self.category = category

        let id = exerciseId
        self._models = Query(filter: #Predicate<ExerciseModel> { $0.id == id })

        let coordinatorCache = Container.shared.trainingCoordinatorCache()
        let coordinator = coordinatorCache.coordinator(for: category)
        self.trainingCoordinator = coordinator
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Button(action: { dismissTrainingSheet() }) {
                    Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
                .accessibilityLabel(AppText.accessibilityCloseTraining)
                .accessibilityIdentifier(TrainingIDs.sheetBackdrop)

                if let model = models.first, trainingCoordinator.isTrainingActive {
                    sheetContent(model: model)
                        .offset(y: max(0, dragTranslation))
                        .animation(.interactiveSpring(
                            response: 0.3,
                            dampingFraction: 0.8
                        ), value: dragTranslation)
                        .frame(
                            maxHeight: max(
                                0,
                                geometry.size.height
                                    - AppStyle.Layout.trainingSheetMinimumBackdropHeight
                            ),
                            alignment: .bottom
                        )

                    TrainingPickerComponent(
                        coordinator: trainingCoordinator,
                        sheetHeight: sheetHeightLatch.height
                    )

                    FeedbackSheetComponent(
                        coordinator: trainingCoordinator,
                        category: category,
                        initialDetentHeight: sheetHeightLatch.height
                    )
                }

                if overlayState.showTrainingMiniMenu {
                    miniMenuOverlay
                }

                if formViewModel.showForm {
                    seatPicker
                }
            }
        }
        .onAppear {
            startTrainingIfReady()
            dismissIfExerciseIsMissing()
        }
        .onChange(of: models.first?.id) { _, _ in
            startTrainingIfReady()
            dismissIfExerciseIsMissing()
        }
        .onChange(of: trainingCoordinator.isTrainingActive) { _, isActive in
            handleTrainingActivityChange(isActive)
        }
        .onDisappear {
            overlayState.showTrainingMiniMenu = false
        }
    }

    /// Anything presented over the training sheet. The sheet's own content
    /// changes while one of these is up, so `TrainingSheetHeightLatch` must not
    /// take a measurement then.
    private var isOverlaySheetPresented: Bool {
        trainingCoordinator.isFeedbackSheetPresented
            || trainingCoordinator.focusedSession?.isEditing == true
            || formViewModel.showForm
    }

    private func sheetContent(model: ExerciseModel) -> some View {
        VStack(spacing: 0) {
            dragRegion

            TrainingSessionComponent(
                coordinator: trainingCoordinator,
                onEdit: { exercise, mode in
                    guard mode == .seat else { return }
                    withAnimation {
                        formViewModel.loadExercise(exercise, category: category)
                        formViewModel.editMode = .seat
                        formViewModel.showForm = true
                    }
                },
                onCancel: { cancelTraining() }
            )

            TrainingActionBarComponent(
                coordinator: trainingCoordinator,
                exercises: [model.toDomain()],
                hasActiveExercise: trainingCoordinator.isTrainingActive
            )
            .padding(.top, AppStyle.Layout.trainingSheetActionBarTopSpacing)
            .offset(y: 10)

            Color.clear
                .frame(height: AppStyle.Layout.trainingSheetBottomBarClearance)
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { visibleHeight in
            // Measure the visible card itself, before the outer max-height
            // constraint can contribute transparent layout space. Native
            // fixed detents already resolve against the visible sheet height.
            sheetHeightLatch.record(
                visibleHeight,
                overlayPresented: isOverlaySheetPresented
            )
        }
        // Shape, ambient washes and border all come from the shared surface —
        // this sheet defines the height its siblings adopt, so it must not
        // describe its own surface alongside them.
        .background { AmbientSheetSurface() }
        .overlay {
            // The one thing this sheet adds: a corner glow the sibling sheets
            // deliberately do not carry.
            AmbientSheetSurface.shape
                .fill(
                    RadialGradient(
                        colors: [
                            AppStyle.Color.idleCardInnerGlow,
                            .clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TrainingIDs.sheet)
    }


    /// The grabber plus the empty band below it. That gap is layout the sheet
    /// already had, so folding it into the drag target widens the grip from the
    /// grabber's ~23pt to the full header without moving anything or covering
    /// content the way an overlay would.
    private var dragRegion: some View {
        VStack(spacing: 0) {
            sheetHeader

            Color.clear
                .frame(height: AppStyle.Layout.trainingSheetHeaderSpacing)
        }
        .contentShape(Rectangle())
        .gesture(sheetDragGesture)
    }

    private var sheetHeader: some View {
        SheetGrabber()
            .accessibilityElement()
            .accessibilityLabel(AppText.accessibilityCloseTraining)
            .accessibilityHint(AppText.accessibilityCloseTrainingHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismissTrainingSheet() }
            .accessibilityIdentifier(TrainingIDs.sheetGrabber)
    }

    /// Mirrors the pattern the feedback and add-friend sheets already use:
    /// `updating` drives the live offset, `onEnded` decides at the same 80pt
    /// threshold as before. Releasing below it drops `dragTranslation` back to
    /// zero and the animation carries the sheet home.
    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 80 {
                    dismissTrainingSheet()
                }
            }
    }

    private var seatPicker: some View {
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
        .hidesBottomBarWhilePresented(overlayState)
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
                                id: "cancel-training",
                                icon: "xmark",
                                title: AppText.actionCancel,
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
                .padding(.bottom, safeAreaInsets.bottom - 50)
            }
            .transition(.opacity)
            .zIndex(4)
        }
    }

    private func startTrainingIfReady() {
        guard phase == .waitingForQuery, let model = models.first else { return }
        let result: StartTrainingResult?
        if let workoutId = model.workoutId {
            result = trainingCoordinator.startTraining(
                for: model.toDomain(),
                workoutId: workoutId
            )
        } else {
            result = trainingCoordinator.startTraining(for: model.toDomain())
        }
        guard result != nil else {
            router.dismissTraining()
            return
        }
        phase = .active
    }

    /// Verifies the one exceptional empty-query case without a timing guess.
    /// `@Query` remains the live rendering source; this targeted fetch only
    /// distinguishes an absent row from a query that has not published yet.
    private func dismissIfExerciseIsMissing() {
        guard models.first == nil,
              router.trainingPresentation?.exerciseId == exerciseId else {
            return
        }

        let id = exerciseId
        let descriptor = FetchDescriptor<ExerciseModel>(
            predicate: #Predicate<ExerciseModel> { $0.id == id }
        )
        guard let count = try? modelContext.fetchCount(descriptor), count == 0 else {
            return
        }

        router.dismissTraining()
    }

    private func handleTrainingActivityChange(_ isActive: Bool) {
        if !isActive && phase == .active {
            phase = .finishing
            overlayState.showTrainingMiniMenu = false
            router.dismissTraining()
        }
    }

    private func dismissTrainingSheet() {
        overlayState.showTrainingMiniMenu = false
        router.dismissTraining()
    }

    private func saveSeat() {
        let trimmed = formViewModel.seat.trimmingCharacters(in: .whitespaces)
        let newSeat: String? = trimmed.isEmpty ? nil : trimmed
        trainingCoordinator.updateActiveSeat(newSeat)
        formViewModel.clearForm()
    }

    private func cancelTraining() {
        overlayState.showTrainingMiniMenu = false

        trainingCoordinator.cancelTraining()
        router.dismissTraining()
    }

    #Preview {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: WorkoutModel.self,
            ExerciseModel.self,
            WorkoutExerciseOrderModel.self,
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
            weight: 20,
            reps: 12,
            sets: 3,
            iconName: "defaultChestIcon",
            category: MuscleCategoryGroup.chest.rawValue,
            workout: workout
        )
        context.insert(model)
        try? context.save()

        let router = AppRouter()
        router.presentTraining(exerciseId: model.id, category: .chest)

        return ZStack {
            AppStyle.Color.backgroundColor.ignoresSafeArea()
            TrainingSheetView(exerciseId: model.id, category: .chest)
        }
        .environment(UIOverlayState())
        .environment(router)
        .modelContainer(container)
    }
}
