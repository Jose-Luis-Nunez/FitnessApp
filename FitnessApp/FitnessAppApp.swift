import SwiftUI
import SwiftData
import UIKit
import FitnessCore
import FitnessStorage
import FitnessUI
import FitnessExercise
import FitnessAnalytics
import FitnessSchedule
import FitnessTraining
import FitnessWorkouts
import Factory

@main
struct FitnessAppApp: App {
    private let launchStrategy: any AppLaunchStrategy
    private let modelContainer: ModelContainer

    init() {
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.layer.shadowOpacity = 0
        textFieldAppearance.layer.shadowRadius = 0
        textFieldAppearance.backgroundColor = .clear

        let container = Container.shared.modelContainer()
        self.modelContainer = container
        DataMigrationService.migrateIfNeeded(context: container.mainContext)

        #if UITESTING
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let config = UITestLaunchConfig.from(
               environment: ProcessInfo.processInfo.environment
           ) {
            launchStrategy = UITestLaunchStrategy(config: config)
        } else {
            launchStrategy = ProductionLaunchStrategy()
        }
        #else
        launchStrategy = ProductionLaunchStrategy()
        #endif
    }

    @State private var router = AppRouter()
    @State private var overlayState = UIOverlayState()
    @State private var workoutStorageService = Container.shared.workoutStorage()
    @State private var didLaunch: Bool = false

    var body: some Scene {
        WindowGroup {
            GeometryReader { geo in
            ZStack(alignment: .bottom) {
                @Bindable var routerBindable = router
                NavigationStack(path: $routerBindable.path) {
                    WorkoutsScreen()
                        .onAppear {
                            guard !didLaunch, router.isEmpty else { return }
                            launchStrategy.prepare(workoutService: workoutStorageService)
                            launchStrategy.configureEnvironment()
                            let stack = launchStrategy.initialNavigationStack(
                                workoutService: workoutStorageService
                            )
                            if !stack.isEmpty {
                                router.replaceAll(with: stack)
                            }
                            didLaunch = true
                        }
                    .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            Group {
                                switch destination {
                                case .home:
                                    MuscleCategorySelectionView()
                                        .navigationBarBackButtonHidden(true)
                                case .profile:
                                    ProfileView()
                                        .navigationBarBackButtonHidden(true)
                                case .totalAnalytics:
                                    TotalAnalyticsView()
                                        .navigationBarBackButtonHidden(true)
                                case .schedule:
                                    ScheduleView()
                                        .navigationBarBackButtonHidden(true)
                                case .muscleCategory(let group):
                                    MuscleCategoryView(group: group)
                                        .navigationBarBackButtonHidden(true)
                                case .training(let exercise, let category):
                                    TrainingView(exercise: exercise, category: category)
                                        .navigationBarBackButtonHidden(true)
                                }
                            }
                            .enableSwipeBack()
                        }
                }
                .zIndex(overlayState.isEditingSheetVisible ? 2 : 0)
                let showBack = !router.isEmpty

                BottomMenuBarView(
                    showBackButton: showBack,
                    narrowBy: 50,
                    onRightAction: {
                        switch router.currentScene {
                        case .home:
                            overlayState.showSelectionMiniMenu.toggle()
                        case .category:
                            overlayState.showCategoryMiniMenu.toggle()
                        case .workouts:
                            overlayState.showWorkoutsMiniMenu.toggle()
                        case .profile, .schedule, .analytics:
                            break
                        case .training:
                            overlayState.showTrainingMiniMenu.toggle()
                        }
                    },
                    customBackAction: router.currentScene == .training ? {
                        if overlayState.isCancellingTraining {
                            return
                        }
                        router.pop()
                    } : nil
                )
                .zIndex((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .opacity((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .allowsHitTesting(!(overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu))
            }
            .environment(\.safeAreaInsets, geo.safeAreaInsets)
            .environment(overlayState)
            .environment(router)
            }
            .modelContainer(modelContainer)
        }
    }
}
