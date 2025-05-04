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
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            switch destination {
                            case .home:
                                MuscleCategorySelectionView()
                                    .onAppear {
                                        print("Navigated to MuscleCategorySelectionView (home)")
                                    }
                            case .profile:
                                ProfileView()
                                    .onAppear {
                                        print("Navigated to ProfileView")
                                    }
                            case .muscleCategory(let group):
                                MuscleCategoryView(group: group)
                                    .onAppear {
                                        print("Navigated to MuscleCategoryView for group: \(group.displayName)")
                                    }
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
