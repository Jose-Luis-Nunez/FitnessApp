import SwiftUI

enum NavigationDestination: Hashable {
    case workouts
    case home
    case profile
    case totalAnalytics
    case muscleCategory(MuscleCategoryGroup)
}

@main
struct FitnessAppApp: App {
    @State private var navigationPath = NavigationPath()
    @StateObject private var overlayState = UIOverlayState()
    @StateObject private var workoutStorageService = WorkoutStorageService.shared
    @State private var isShowingWorkoutsRoot: Bool = false
    @State private var didAutoNavigateToHome: Bool = false
    private enum CurrentScene { case workouts, home, profile, category }
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
                                }
                            }
                            .onAppear {
                                if case .muscleCategory(let group) = destination {
                                    print("Navigated to MuscleCategoryView for group: \(group.displayName)")
                                } else if case .profile = destination {
                                    print("Navigated to ProfileView")
                                } else if case .home = destination {
                                    print("Navigated to MuscleCategorySelectionView (home)")
                                }
                                print("Navigation path count: \(navigationPath.count)")
                            }
                        }
                        .onAppear {
                            print("Root NavigationStack appeared - path: \(navigationPath)")
                        }
                        .onChange(of: navigationPath) { oldPath, newPath in
                            print("Navigation path changed from \(oldPath) to \(newPath)")
                        }
                }
                .zIndex(overlayState.isEditingSheetVisible ? 2 : 0)
                let showBack = !navigationPath.isEmpty
                let rightStyle: BottomBarRightActionStyle = {
                    switch currentScene {
                    case .home: return .menu
                    case .category, .workouts, .profile: return .menu
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
                        }
                    }
                )
                .zIndex((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu) ? 0 : 1)
                .opacity((overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu) ? 0 : 1)
                .allowsHitTesting(!(overlayState.isEditingSheetVisible || overlayState.showCategoryMiniMenu || overlayState.showSelectionMiniMenu || overlayState.showWorkoutsMiniMenu))
            }
            .environmentObject(overlayState)
        }
    }
}
