import SwiftUI
import FitnessCore
import FitnessUI
import FitnessExercise
import Factory

private enum Constants {
    static let horizontalPadding: CGFloat = AppStyle.Padding.screenHorizontal
    static let verticalSpacing: CGFloat = 12
    static let titleTopPadding: CGFloat = AppStyle.Padding.titleTop
    static let titleBottomSpacing: CGFloat = AppStyle.Padding.titleBottom
    static let topPadding: CGFloat = 1

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
                                MiniActionMenuItem(icon: "plus", title: "New workout", isDestructive: false) {
                                    overlayState.showWorkoutsMiniMenu = false
                                    viewModel.showCreateWorkout()
                                },
                                MiniActionMenuItem(icon: "square.and.arrow.down", title: "Import workout", isDestructive: false) {
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
        .alert("Export fehlgeschlagen", isPresented: Binding(
            get: { viewModel.exportErrorMessage != nil },
            set: { if !$0 { viewModel.exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.exportErrorMessage = nil }
        } message: {
            Text(viewModel.exportErrorMessage ?? "")
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
                        // A workout is a targeted entry — open it as a root-like
                        // screen so there is no back-navigation to the list.
                        router.replaceAll(with: [.home])
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
                                    list.append(MiniActionMenuItem(icon: nil, title: "Export workout", isDestructive: false) {
                                        if let workout = viewModel.selectedWorkoutForAction {
                                            viewModel.requestShare(for: workout)
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

