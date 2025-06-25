import SwiftUI

enum NavigationDestination: Hashable {
    case home
    case profile
    case muscleCategory(MuscleCategoryGroup)
}

@main
struct FitnessAppApp: App {
    @State private var navigationPath = NavigationPath()
    
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                NavigationStack(path: $navigationPath) {
                    MuscleCategorySelectionView()
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
                BottomMenuBarView(
                    barHeight: 40,
                    onAddExercise: {},
                    backgroundColor: backgroundColor,
                    navigationPath: $navigationPath
                )
            }
        }
    }
}
