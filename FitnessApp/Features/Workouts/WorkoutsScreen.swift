import SwiftUI
import FitnessCore
import FitnessStorage
import FitnessUI
import FitnessExercise

private enum Constants {
    static let horizontalPadding: CGFloat = AppStyle.Padding.screenHorizontal
    static let verticalSpacing: CGFloat = 12
    static let titleTopPadding: CGFloat = AppStyle.Padding.titleTop
    static let titleBottomSpacing: CGFloat = AppStyle.Padding.titleBottom
    static let topPadding: CGFloat = 1

    enum WorkoutTile {
        static let contentPadding: CGFloat = 20
        static let cornerRadius: CGFloat = AppStyle.CornerRadius.defaultButton
        static let iconSize: CGFloat = 24
        static let spacing: CGFloat = 12
        static let verticalPadding: CGFloat = 16
    }

    enum FAB {
        static let mainSize: CGFloat = 56
        static let optionSize: CGFloat = 48
        static let spacing: CGFloat = 16
        static let bottomPadding: CGFloat = 20
        static let trailingPadding: CGFloat = 20
        static let optionOffset: CGFloat = 64
        static let fabSpacing: CGFloat = 16
    }
}

struct WorkoutsScreen: View {
    @State private var viewModel = WorkoutsViewModel()
    @Environment(AppRouter.self) private var router
    @Environment(UIOverlayState.self) private var overlayState
    
    var body: some View {
        ZStack {
            mainContent
            // Mini menu for creating a new workout, opened from the ellipsis in bottom bar
            if overlayState.showWorkoutsMiniMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { overlayState.showWorkoutsMiniMenu = false }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniActionMenuView(
                            title: nil,
                            items: [
                                MiniActionMenuItem(icon: "plus", title: "New workout", isDestructive: false) {
                                    overlayState.showWorkoutsMiniMenu = false
                                    viewModel.showCreateWorkout()
                                }
                            ]
                        )
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, safeAreaInset - 50)
                }
                .transition(.opacity)
                .zIndex(3)
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitle("")
        .fullScreenCover(isPresented: $viewModel.showingCreateWorkoutFullScreen) {
            CreateWorkoutView(
                workoutName: $viewModel.newWorkoutName,
                isPresented: $viewModel.showingCreateWorkoutFullScreen,
                onSave: {
                    viewModel.createNewWorkout()
                },
                viewModel: viewModel
            )
        }
        .fullScreenCover(isPresented: $viewModel.showingRenameWorkout) {
            RenameWorkoutView(
                workoutName: $viewModel.renameWorkoutName,
                isPresented: $viewModel.showingRenameWorkout,
                workoutToRename: viewModel.selectedWorkoutForAction ?? Workout(name: ""),
                onSave: {
                    viewModel.renameWorkout()
                }
                        )
        }
        .overlay(
            settingsMiniMenu
        )

      }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView {
                LazyVStack(spacing: Constants.verticalSpacing) {
                    workoutsGrid
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.top, Constants.topPadding)
                .padding(.bottom, Constants.FAB.bottomPadding)
            }
        }
    }
    
    private var headerView: some View {
        Text("Meine Workouts")
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.titleTopPadding)
            .padding(.bottom, Constants.titleBottomSpacing)
    }
    
    private var workoutsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: Constants.verticalSpacing),
            GridItem(.flexible(), spacing: Constants.verticalSpacing)
        ]
        
        return LazyVGrid(columns: columns, spacing: Constants.verticalSpacing) {
            ForEach(viewModel.workouts) { workout in
                WorkoutTileView(
                    workout: workout,
                    isDefault: viewModel.isDefaultWorkout(workout),
                    exerciseCount: viewModel.getExerciseCount(for: workout),
                    onTap: {
                        viewModel.selectWorkout(workout)
                        router.navigate(to: .home)
                    },
                    onLongPress: {
                        viewModel.showFABOptions(for: workout)
                    },
                    onSettingsTap: {
                        viewModel.showFABOptions(for: workout)
                    }
                )
            }
        }
    }
    
    
    private var settingsMiniMenu: some View {
        Group {
            if viewModel.showingFABOptions {
                ZStack {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.hideFABOptions() }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            let items: [MiniActionMenuItem] = {
                                if viewModel.showingDeleteConfirmation {
                                    return [
                                        MiniActionMenuItem(icon: nil, title: "Confirm deletion", isDestructive: true) {
                                            viewModel.confirmDelete()
                                        },
                                        MiniActionMenuItem(icon: nil, title: "Cancel", isDestructive: false) {
                                            viewModel.cancelDelete()
                                        }
                                    ]
                                } else {
                                    var list: [MiniActionMenuItem] = []
                                    list.append(MiniActionMenuItem(icon: nil, title: "duplicate", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.duplicateWorkout(workout)
                                            viewModel.hideFABOptions()
                                        }
                                    })
                                    list.append(MiniActionMenuItem(icon: nil, title: "Rename", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.showRenameWorkout(for: workout)
                                        }
                                    })
                                    if let workout = viewModel.selectedWorkoutForAction {
                                        if viewModel.isDefaultWorkout(workout) {
                                            list.append(MiniActionMenuItem(icon: nil, title: "Remove as Default", isDestructive: false) {
                                                viewModel.removeAsDefault()
                                                viewModel.hideFABOptions()
                                            })
                                        } else {
                                            list.append(MiniActionMenuItem(icon: nil, title: "Set as Default", isDestructive: false) {
                                                viewModel.setAsDefault(workout)
                                                viewModel.hideFABOptions()
                                            })
                                        }
                                    }
                                    if viewModel.canDeleteWorkout {
                                        list.append(MiniActionMenuItem(icon: nil, title: "Delete", isDestructive: true) {
                                            viewModel.showDeleteConfirmation()
                                        })
                                    }
                                    return list
                                }
                            }()

                            MiniActionMenuView(
                                title: viewModel.selectedWorkoutForAction?.name,
                                items: items
                            )
                            .padding(.trailing, 16)
                        }
                        .padding(.bottom, safeAreaInset - 50)
                    }

                }
                .transition(.opacity)
                .zIndex(3)
                .onAppear { overlayState.showWorkoutSettingsMenu = true }
                .onDisappear { overlayState.showWorkoutSettingsMenu = false }
            }
        }
    }
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaInset: CGFloat { safeAreaInsets.bottom }
}

private struct WorkoutTileView: View {
    let workout: Workout
    let isDefault: Bool
    let exerciseCount: Int
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header mit Settings
                HStack {
                    Spacer()
                    Button(action: onSettingsTap) {
                        Image("settingsIconMenu")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(AppStyle.Color.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 6)
                
                Spacer()
                
                // Workout Name zentriert
                Text(workout.name)
                    .font(AppStyle.Font.categorySelectionNameFont)
                    .foregroundColor(AppStyle.Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Constants.WorkoutTile.cornerRadius)
                    .fill(isDefault ? AppStyle.Color.green.opacity(0.2) : AppStyle.Color.exerciseCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.WorkoutTile.cornerRadius)
                            .stroke(isDefault ? AppStyle.Color.green : Color.clear, lineWidth: 2)
                    )
            )
            .overlay(
                // Exercise Count Circle - top left overlay
                VStack {
                    HStack {
                        ZStack {
                            // Äußerer Ring (dicker)
                            Circle()
                                .stroke(
                                    isDefault ? AppStyle.Color.green : Color.white.opacity(0.6),
                                    lineWidth: 3
                                )
                                .frame(width: 34, height: 34)
                            
                            // Innerer Ring (dünner)
                            Circle()
                                .stroke(
                                    isDefault ? AppStyle.Color.green.opacity(0.4) : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                                .frame(width: 26, height: 26)
                            
                            Text("\(exerciseCount)")
                                .font(AppStyle.Font.detailBadge)
                                .foregroundColor(isDefault ? AppStyle.Color.green : Color.white)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    Spacer()
                }
            )
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
} 
