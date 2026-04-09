import SwiftUI
import UIKit

enum NavigationDestination: Hashable {
    case workouts
    case home
    case profile
    case totalAnalytics
    case schedule
    case muscleCategory(MuscleCategoryGroup)
    case training(Exercise, MuscleCategoryGroup)
}

@main
struct FitnessAppApp: App {
    init() {
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.layer.shadowOpacity = 0
        textFieldAppearance.layer.shadowRadius = 0
        textFieldAppearance.backgroundColor = .clear
    }

    @State private var navigationPath = NavigationPath()
    @StateObject private var overlayState = UIOverlayState()
    @StateObject private var workoutStorageService = WorkoutStorageService.shared
    @State private var isShowingWorkoutsRoot: Bool = false
    @State private var didAutoNavigateToHome: Bool = false
    
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    // Always start on Workouts as the root. If a default workout exists,
                    // we automatically push to Category Selection to preserve correct back animation.
                    WorkoutsScreen(navigationPath: $navigationPath)
                        .onAppear {
                            if isUITesting {
                                isShowingWorkoutsRoot = navigationPath.isEmpty
                                if navigationPath.isEmpty {
                                    overlayState.currentScene = .workouts
                                }
                                return
                            }
                            if let defaultWorkout = workoutStorageService.defaultWorkout,
                               navigationPath.isEmpty,
                               didAutoNavigateToHome == false {
                                workoutStorageService.setCurrentWorkout(defaultWorkout)
                                navigationPath.append(NavigationDestination.home)
                                didAutoNavigateToHome = true
                                isShowingWorkoutsRoot = false
                                overlayState.currentScene = .home
                            } else {
                                isShowingWorkoutsRoot = navigationPath.isEmpty
                                overlayState.currentScene = .workouts
                            }
                        }
                    .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            Group {
                                switch destination {
                                case .workouts:
                                    WorkoutsScreen(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { 
                                            isShowingWorkoutsRoot = true
                                            overlayState.currentScene = .workouts
                                        }
                                case .home:
                                    MuscleCategorySelectionView(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { 
                                            isShowingWorkoutsRoot = false
                                            overlayState.currentScene = .home
                                        }
                                case .profile:
                                    ProfileView()
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; overlayState.currentScene = .profile }
                                case .totalAnalytics:
                                    TotalAnalyticsView()
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; overlayState.currentScene = .home }
                                case .schedule:
                                    ScheduleView()
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; overlayState.currentScene = .schedule }
                                case .muscleCategory(let group):
                                    MuscleCategoryView(group: group, navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { 
                                            isShowingWorkoutsRoot = false
                                            overlayState.currentScene = .category
                                        }
                                case .training(let exercise, let category):
                                    TrainingView(exercise: exercise, category: category, navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { 
                                            isShowingWorkoutsRoot = false
                                            overlayState.currentScene = .training
                                        }
                                }
                            }
                            .enableSwipeBack()
                        }
                }
                .zIndex(overlayState.isEditingSheetVisible ? 2 : 0)
                let showBack = !navigationPath.isEmpty
                let rightStyle: BottomBarRightActionStyle = {
                    switch overlayState.currentScene {
                    case .home: return .menu
                    case .category, .workouts, .profile, .schedule: return .menu
                    case .training: return .menu
                    }
                }()

                BottomMenuBarView(
                    navigationPath: $navigationPath,
                    showBackButton: showBack,
                    narrowBy: 50,
                    rightActionStyle: rightStyle,
                    onRightAction: {
                        switch overlayState.currentScene {
                        case .home:
                            overlayState.showSelectionMiniMenu.toggle()
                        case .category:
                            overlayState.showCategoryMiniMenu.toggle()
                        case .workouts:
                            overlayState.showWorkoutsMiniMenu.toggle()
                        case .profile, .schedule:
                            break
                        case .training:
                            overlayState.showTrainingMiniMenu.toggle()
                        }
                    },
                    customBackAction: overlayState.currentScene == .training ? {
                        // Don't override navigation if training is being cancelled
                        if overlayState.isCancellingTraining {
                            return // Let TrainingView handle cancel navigation
                        }
                        
                        // Normal back navigation: direct jump to CategorySelectionView
                        var newPath = NavigationPath()
                        newPath.append(NavigationDestination.home)
                        navigationPath = newPath
                    } : nil
                )
                .zIndex((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .opacity((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .allowsHitTesting(!(overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu))
            }
            .environmentObject(overlayState)
            .onAppear {
                #if UITESTING
                if isUITesting { configureUITestEnvironment() }
                #endif
            }
        }
    }

    #if UITESTING
    private func configureUITestEnvironment() {
        UITestRouter.speedUpAnimations()
        guard let config = UITestLaunchConfig.from(
            environment: ProcessInfo.processInfo.environment
        ) else { return }
        UITestRouter.configure(
            config: config,
            navigationPath: &navigationPath,
            workoutStorageService: workoutStorageService
        )
    }
    #endif // UITESTING
}
