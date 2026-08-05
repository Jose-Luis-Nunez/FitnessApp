import SwiftUI
import FitnessCore
import FitnessUI
import FitnessExercise
import FitnessAnalytics
import Factory

private enum Constants {
    static let horizontalPadding: CGFloat = ExerciseCardLayout.CategoryTile.gridHorizontalPadding
    static let workoutGridSpacing: CGFloat = ExerciseCardLayout.CategoryTile.gridSpacing
    static let titleTopPadding: CGFloat = AppStyle.Padding.titleTop
    static let titleBottomSpacing: CGFloat = AppStyle.Padding.titleBottom
}

public struct WorkoutsScreen: View {
    @State private var viewModel = WorkoutsViewModel()
    @State private var importCoordinator = Container.shared.workoutImportCoordinator()
    @Environment(AppRouter.self) private var router
    @Environment(UIOverlayState.self) private var overlayState

    public init() {}

    public var body: some View {
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
                                MiniActionMenuItem(id: "new-workout", icon: "plus", title: "New workout", isDestructive: false) {
                                    overlayState.showWorkoutsMiniMenu = false
                                    viewModel.showCreateWorkout()
                                },
                                MiniActionMenuItem(id: "import-workout", icon: "square.and.arrow.down", title: "Import workout", isDestructive: false) {
                                    overlayState.showWorkoutsMiniMenu = false
                                    viewModel.showImportWorkout()
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
        .overlay {
            if viewModel.showingCreateWorkoutFullScreen {
                CreateWorkoutView(
                    workoutName: $viewModel.newWorkoutName,
                    workoutType: $viewModel.newWorkoutType,
                    isPresented: $viewModel.showingCreateWorkoutFullScreen,
                    onSave: {
                        viewModel.createNewWorkout()
                    }
                )
                .zIndex(3)
                // Hide the app's glass bottom bar while the sheet is up,
                // otherwise it floats over the Cancel/Save buttons.
                .hidesBottomBarWhilePresented(overlayState)
            }
        }
        .fullScreenCover(item: workoutAnalyticsEntryItem) { workout in
            WorkoutAnalyticsEntryView(
                workout: workout,
                isPresented: workoutAnalyticsEntryPresentation
            )
            .hidesBottomBarWhilePresented(overlayState)
            .interactiveDismissDisabled()
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
        .workoutImportFlow(viewModel: viewModel, coordinator: importCoordinator)
        .sheet(item: $viewModel.workoutToShare) { item in
            // Prefer the file URL so iOS treats the export as a real file
            // attachment (Mail/AirDrop/Save-to-Files/Notes). Falls back to the
            // raw JSON string if file-write failed during `requestShare`.
            ShareSheet(items: [item.fileURL ?? item.json as Any], tempFileURL: item.fileURL)
        }
        .alert("Export failed", isPresented: Binding(
            get: { viewModel.exportErrorMessage != nil },
            set: { if !$0 { viewModel.exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.exportErrorMessage = nil }
        } message: {
            Text(viewModel.exportErrorMessage ?? "")
        }
        .alert("Workout creation failed", isPresented: Binding(
            get: { viewModel.createErrorMessage != nil },
            set: { if !$0 { viewModel.createErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.createErrorMessage = nil }
        } message: {
            Text(viewModel.createErrorMessage ?? "")
        }
        .overlay(
            settingsMiniMenu
        )
        .onAppear { viewModel.refreshExerciseCounts() }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            ScrollView {
                if let exerciseCounts = viewModel.exerciseCounts {
                    workoutsGrid(exerciseCounts: exerciseCounts)
                        .padding(.horizontal, Constants.horizontalPadding)
                        .padding(.bottom, AppStyle.Layout.workoutGridBottomPadding)
                }
            }
        }
    }

    private var headerView: some View {
        Text("My Workouts")
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.titleTopPadding)
            .padding(.bottom, Constants.titleBottomSpacing)
    }

    private func workoutsGrid(exerciseCounts: [UUID: Int]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: Constants.workoutGridSpacing),
            GridItem(.flexible(), spacing: Constants.workoutGridSpacing)
        ]

        return LazyVGrid(columns: columns, spacing: Constants.workoutGridSpacing) {
            ForEach(viewModel.workouts) { workout in
                WorkoutTileView(
                    workout: workout,
                    isDefault: viewModel.isDefaultWorkout(workout),
                    exerciseCount: exerciseCounts[workout.id, default: 0],
                    onTap: {
                        viewModel.selectWorkout(workout)
                        // Keep the workout list on the navigation stack so the
                        // category selection can return to it.
                        router.navigate(to: .home)
                    },
                    layout: .hero,
                    onLongPress: {
                        viewModel.showWorkoutOptions(for: workout)
                    },
                    onSettingsTap: {
                        viewModel.showWorkoutOptions(for: workout)
                    }
                )
            }
        }
    }

    private var settingsMiniMenu: some View {
        Group {
            if viewModel.showingWorkoutOptions {
                ZStack {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture { viewModel.hideWorkoutOptions() }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            let items: [MiniActionMenuItem] = {
                                if viewModel.showingDeleteConfirmation {
                                    return [
                                        MiniActionMenuItem(id: "confirm-delete-workout", icon: nil, title: "Confirm deletion", isDestructive: true) {
                                            viewModel.confirmDelete()
                                        },
                                        MiniActionMenuItem(id: "cancel-delete-workout", icon: nil, title: "Cancel", isDestructive: false) {
                                            viewModel.cancelDelete()
                                        }
                                    ]
                                } else {
                                    var list: [MiniActionMenuItem] = []
                                    if let workout = viewModel.selectedWorkoutForAction,
                                       viewModel.hasActiveExercises(in: workout) {
                                        list.append(
                                            MiniActionMenuItem(
                                                id: "log-workout",
                                                icon: "calendar.badge.plus",
                                                title: "Log Workout",
                                                isDestructive: false
                                            ) {
                                                viewModel.showWorkoutAnalyticsEntry(for: workout)
                                            }
                                        )
                                    }
                                    list.append(MiniActionMenuItem(id: "duplicate-workout", icon: nil, title: "duplicate", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.duplicateWorkout(workout)
                                            viewModel.hideWorkoutOptions()
                                        }
                                    })
                                    list.append(MiniActionMenuItem(id: "export-workout", icon: nil, title: "Export workout", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.requestShare(for: workout)
                                        }
                                    })
                                    list.append(MiniActionMenuItem(id: "rename-workout", icon: nil, title: "Rename", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.showRenameWorkout(for: workout)
                                        }
                                    })
                                    if let workout = viewModel.selectedWorkoutForAction {
                                        if viewModel.isDefaultWorkout(workout) {
                                            list.append(MiniActionMenuItem(id: "remove-default-workout", icon: nil, title: "Remove as Default", isDestructive: false) {
                                                viewModel.removeAsDefault()
                                                viewModel.hideWorkoutOptions()
                                            })
                                        } else {
                                            list.append(MiniActionMenuItem(id: "set-default-workout", icon: nil, title: "Set as Default", isDestructive: false) {
                                                viewModel.setAsDefault(workout)
                                                viewModel.hideWorkoutOptions()
                                            })
                                        }
                                    }
                                    if viewModel.canDeleteWorkout {
                                        list.append(MiniActionMenuItem(id: "delete-workout", icon: nil, title: "Delete", isDestructive: true) {
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

    private var workoutAnalyticsEntryPresentation: Binding<Bool> {
        Binding(
            get: { viewModel.workoutForAnalyticsEntry != nil },
            set: { if !$0 { viewModel.dismissWorkoutAnalyticsEntry() } }
        )
    }

    private var workoutAnalyticsEntryItem: Binding<Workout?> {
        Binding(
            get: { viewModel.workoutForAnalyticsEntry },
            set: { workout in
                viewModel.workoutForAnalyticsEntry = workout
            }
        )
    }
}
