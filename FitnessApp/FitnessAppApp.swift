import SwiftUI

enum NavigationDestination: Hashable {
    case workouts
    case home
    case profile
    case muscleCategory(MuscleCategoryGroup)
}

@main
struct FitnessAppApp: App {
    @State private var navigationPath = NavigationPath()
    @StateObject private var overlayState = UIOverlayState()
    @StateObject private var workoutStorageService = WorkoutStorageService.shared
    
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    Group {
                        if let defaultWorkout = workoutStorageService.defaultWorkout {
                            MuscleCategorySelectionView(navigationPath: $navigationPath)
                                .onAppear {
                                    workoutStorageService.setCurrentWorkout(defaultWorkout)
                                }
                        } else {
                            WorkoutsScreen(navigationPath: $navigationPath)
                        }
                    }
                    .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            Group {
                                switch destination {
                                case .workouts:
                                    WorkoutsScreen(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                case .home:
                                    MuscleCategorySelectionView(navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
                                case .profile:
                                    ProfileView()
                                        .navigationBarBackButtonHidden(true)
                                case .muscleCategory(let group):
                                    MuscleCategoryView(group: group, navigationPath: $navigationPath)
                                        .navigationBarBackButtonHidden(true)
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
                BottomMenuBarView(
                    barHeight: 40,
                    onAddExercise: {},
                    backgroundColor: backgroundColor,
                    navigationPath: $navigationPath
                )
                .zIndex(overlayState.isEditingSheetVisible ? 0 : 1)
                .opacity(overlayState.isEditingSheetVisible ? 0 : 1)
                .allowsHitTesting(!overlayState.isEditingSheetVisible)
            }
            .environmentObject(overlayState)
        }
    }
}
