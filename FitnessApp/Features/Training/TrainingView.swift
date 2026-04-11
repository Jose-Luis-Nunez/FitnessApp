import SwiftUI
import FitnessCore
import FitnessStorage
import FitnessUI
import FitnessExercise
import FitnessAnalytics
import FitnessTraining
import Factory

struct TrainingView: View {
    let exercise: Exercise
    let category: MuscleCategoryGroup
    
    @Environment(AppRouter.self) private var router
    private var trainingCoordinator: TrainingCoordinator
    @State private var analyticsViewModel: AnalyticsViewModel
    @Environment(UIOverlayState.self) private var overlayState
    
    @State private var cardViewModel: ExerciseCardViewModel
    @State private var hasFinishedTraining = false
    @State private var isInitialLoad = true
    @State private var isManuallyNavigatingBack = false
    
    init(exercise: Exercise, category: MuscleCategoryGroup) {
        self.exercise = exercise
        self.category = category
        
        let coordinatorCache = Container.shared.trainingCoordinatorCache()
        let coordinator = coordinatorCache.coordinator(for: category)
        self.trainingCoordinator = coordinator
        
        self._analyticsViewModel = State(wrappedValue: coordinator.analyticsViewModel)
        let managementService = Container.shared.exerciseManagement()
        self._cardViewModel = State(wrappedValue: ExerciseCardViewModel(exercise: exercise) { updatedExercise in
            managementService.updateExercise(updatedExercise, category: category)
        })
    }
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaBottomInset: CGFloat { safeAreaInsets.bottom }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: trainingCoordinator.isTrainingActive)
            
            // Only show content if training is active
            if trainingCoordinator.isTrainingActive {
                VStack(spacing: 0) {
                    Text(exercise.name)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppStyle.Padding.horizontal)
                        .padding(.top, AppStyle.Padding.titleTop)
                        .padding(.bottom, AppStyle.Padding.titleBottomBeforeActiveCard)
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Active Exercise Card
                            ExerciseCardContainerView(
                                viewModel: cardViewModel,
                                onEdit: { exerciseToEdit, _ in
                                },
                                isEditable: !trainingCoordinator.activeSetViewModel.isSetInProgress,
                                analyticsViewModel: analyticsViewModel,
                                activeSetViewModel: trainingCoordinator.activeSetViewModel,
                                onStart: { exerciseToStart in
                                    // Exercise is already started when view appears
                                },
                                onReset: { exerciseToReset in
                                    trainingCoordinator.resetExercise()
                                },
                                isActiveSetVisible: trainingCoordinator.isTrainingActive,
                                isResetEnabled: exercise.isCompleted
                            )
                            
                            // Training Session (ActiveSetView + TimerView)
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
                
                // Training Action Bar (FABs)
                TrainingActionBarComponent(
                    coordinator: trainingCoordinator,
                    exercises: [exercise],
                    hasActiveExercise: trainingCoordinator.isTrainingActive
                )
                .padding(.bottom, safeAreaBottomInset + 12) // Standard Positionierung
                
                // Training Picker Component
                TrainingPickerComponent(coordinator: trainingCoordinator)
            }
            
            // Training Mini Menu Overlay
            if overlayState.showTrainingMiniMenu {
                // Backdrop to dismiss on outside tap
                Color.black.opacity(0.001)
                    .ignoresSafeArea(.all)
                    .onTapGesture { overlayState.showTrainingMiniMenu = false }

                // Floating menu panel
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: [
                                // Cancel Training
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            trainingCoordinator.startTraining(for: exercise)
            
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                isInitialLoad = false
            }
        }
        .onChange(of: trainingCoordinator.isTrainingActive) { _, isActive in
            if !isActive && !hasFinishedTraining && !isInitialLoad && !isManuallyNavigatingBack && !overlayState.isCancellingTraining {
                hasFinishedTraining = true
                overlayState.showTrainingMiniMenu = false
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    router.pop()
                }
            } else if !isActive && overlayState.isCancellingTraining {
                hasFinishedTraining = true
                overlayState.showTrainingMiniMenu = false
            }
        }
        .onDisappear {
            isManuallyNavigatingBack = true
            overlayState.showTrainingMiniMenu = false
        }
    }
    
    private func cancelTraining() {
        let targetCategory = trainingCoordinator.activeSetViewModel.originalCategory ?? category
        overlayState.isCancellingTraining = true
        overlayState.showTrainingMiniMenu = false
        router.replaceAll(with: [.home, .muscleCategory(targetCategory)])

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            trainingCoordinator.cancelTraining()
            try? await Task.sleep(for: .milliseconds(200))
            overlayState.isCancellingTraining = false
        }
    }
    
    #Preview {
        let sampleExercise = Exercise(
            id: UUID(),
            name: "Sample Exercise",
            weight: 20.0,
            reps: 12,
            sets: 3,
            isCompleted: false,
            iconName: "defaultChestIcon",
            category: .chest
        )
        
        NavigationStack {
            TrainingView(
                exercise: sampleExercise,
                category: .chest
            )
        }
        .environment(UIOverlayState())
        .environment(AppRouter())
    }
}
