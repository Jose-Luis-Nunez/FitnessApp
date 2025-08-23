import SwiftUI

enum NavigationDestination: Hashable {
    case workouts
    case home
    case profile
    case totalAnalytics
    case muscleCategory(MuscleCategoryGroup)
    case training(Exercise, MuscleCategoryGroup)
}

@main
struct FitnessAppApp: App {
    @State private var navigationPath = NavigationPath()
    @StateObject private var overlayState = UIOverlayState()
    @StateObject private var workoutStorageService = WorkoutStorageService.shared
    @State private var isShowingWorkoutsRoot: Bool = false
    @State private var didAutoNavigateToHome: Bool = false
    private enum CurrentScene { case workouts, home, profile, category, training }
    @State private var currentScene: CurrentScene = .workouts
    
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    // Always start on Workouts as the root. If a default workout exists,
                    // we automatically push to Category Selection to preserve correct back animation.
                    WorkoutsScreen(navigationPath: $navigationPath)
                        .onAppear {
                            if let defaultWorkout = workoutStorageService.defaultWorkout,
                               navigationPath.isEmpty,
                               didAutoNavigateToHome == false {
                                workoutStorageService.setCurrentWorkout(defaultWorkout)
                                navigationPath.append(NavigationDestination.home)
                                didAutoNavigateToHome = true
                                isShowingWorkoutsRoot = false
                                currentScene = .home
                            } else {
                                isShowingWorkoutsRoot = navigationPath.isEmpty
                                currentScene = .workouts
                            }
                        }
                    .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            Group {
                                switch destination {
                                case .workouts:
                                    WorkoutsScreen(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = true; currentScene = .workouts }
                                case .home:
                                    MuscleCategorySelectionView(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; currentScene = .home }
                                case .profile:
                                    ProfileView()
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; currentScene = .profile }
                                case .totalAnalytics:
                                    TotalAnalyticsView()
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; currentScene = .home }
                                case .muscleCategory(let group):
                                    MuscleCategoryView(group: group, navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; currentScene = .category }
                                case .training(let exercise, let category):
                                    TrainingView(exercise: exercise, category: category, navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                        .onAppear { isShowingWorkoutsRoot = false; currentScene = .training }
                                }
                            }
                            .onAppear {
                                // Navigation tracking - no debug prints needed in production
                            }
                        }
                        .onAppear {
                            // Root navigation setup - no debug prints needed
                        }
                        .onChange(of: navigationPath) { oldPath, newPath in
                            // Navigation path tracking - no debug prints needed
                        }
                }
                .zIndex(overlayState.isEditingSheetVisible ? 2 : 0)
                let showBack = !navigationPath.isEmpty
                let rightStyle: BottomBarRightActionStyle = {
                    switch currentScene {
                    case .home: return .menu
                    case .category, .workouts, .profile: return .menu
                    case .training: return .menu  // TrainingView has no mini menu, but keep menu icon
                    }
                }()

                BottomMenuBarView(
                    barHeight: 40,
                    onAddExercise: {},
                    backgroundColor: backgroundColor,
                    navigationPath: $navigationPath,
                    showBackButton: showBack,
                    narrowBy: 90,
                    rightActionStyle: rightStyle,
                    onRightAction: {
                        switch currentScene {
                        case .home:
                            overlayState.showSelectionMiniMenu.toggle()
                        case .category:
                            overlayState.showCategoryMiniMenu.toggle()
                        case .workouts:
                            overlayState.showWorkoutsMiniMenu.toggle()
                        case .profile:
                            break
                        case .training:
                            overlayState.showTrainingMiniMenu.toggle()
                        }
                    }
                )
                .zIndex((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutDropdown || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .opacity((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutDropdown || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu) ? 0 : 1)
                .allowsHitTesting(!(overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu || overlayState.showWorkoutDropdown || overlayState.showWorkoutSettingsMenu || overlayState.showTrainingMiniMenu))
            }
            .environmentObject(overlayState)
        }
    }
}
