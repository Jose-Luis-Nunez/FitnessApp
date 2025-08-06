import SwiftUI

private enum Constants {
    static let horizontalPadding: CGFloat = 15
    static let verticalSpacing: CGFloat = 12
    static let titleTopPadding: CGFloat = 0
    static let titleBottomSpacing: CGFloat = 20
    static let topPadding: CGFloat = 1
    
    enum WorkoutTile {
        static let contentPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 12
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
    @StateObject private var viewModel = WorkoutsViewModel()
    @Binding var navigationPath: NavigationPath
    
    init(navigationPath: Binding<NavigationPath> = .constant(NavigationPath())) {
        self._navigationPath = navigationPath
    }
    
    var body: some View {
        ZStack {
            mainContent
            fabButtons
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitle("")
        .fullScreenCover(isPresented: $viewModel.showingCreateWorkoutFullScreen) {
            CreateWorkoutView(
                workoutName: $viewModel.newWorkoutName,
                isPresented: $viewModel.showingCreateWorkoutFullScreen,
                onSave: {
                    viewModel.createNewWorkout()
                }
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
            workoutSettingsModal
        )

      }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: Constants.verticalSpacing) {
                    headerView
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
            .padding(.top, Constants.titleTopPadding)
            .padding(.bottom, Constants.titleBottomSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    onTap: {
                        viewModel.selectWorkout(workout)
                        navigationPath.append(NavigationDestination.home)
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
    
    private var fabButtons: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: Constants.FAB.fabSpacing) {
                    // Add Workout FAB (Plus)
                    addWorkoutFAB
                }
                .padding(.bottom, safeAreaInset + Constants.FAB.bottomPadding)
                .padding(.trailing, Constants.FAB.trailingPadding)
            }
        }
    }
    
    private var addWorkoutFAB: some View {
        Button(action: {
            viewModel.showCreateWorkout()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: Constants.FAB.mainSize, height: Constants.FAB.mainSize)
                .background(AppStyle.Color.green)
                .clipShape(Circle())
        }
    }
    
    private var createWorkoutSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Workout Name", text: $viewModel.newWorkoutName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Neues Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    viewModel.showingCreateWorkout = false
                },
                trailing: Button("Erstellen") {
                    viewModel.createNewWorkout()
                }
                .disabled(viewModel.newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }
    
    private var workoutSettingsModal: some View {
        Group {
            if viewModel.showingFABOptions {
                ZStack {
                    // Dunkel-transparenter Hintergrund
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.hideFABOptions()
                        }
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Settings Modal
                        VStack(spacing: 0) {
                            // Header
                            VStack(spacing: 8) {
                                Text(viewModel.showingDeleteConfirmation ? "Löschen" : "Settings")
                                    .font(AppStyle.Font.navigationHeadline)
                                    .foregroundColor(AppStyle.Color.greenGlow)
                                    .padding(.top, 16)
                                
                                Rectangle()
                                    .fill(AppStyle.Color.greenGlow.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 85)
                            }
                            .padding(.bottom, 12)
                            
                            // Optionen
                            if viewModel.showingDeleteConfirmation {
                                // Lösch-Bestätigung
                                VStack(spacing: 4) {
                                    settingsOption(
                                        icon: "",
                                        title: "Löschen bestätigen",
                                        action: {
                                            viewModel.confirmDelete()
                                        }
                                    )
                                    
                                    settingsOption(
                                        icon: "",
                                        title: "Abbrechen",
                                        action: {
                                            viewModel.cancelDelete()
                                        }
                                    )
                                }
                            } else {
                                // Normal Settings
                                VStack(spacing: 4) {
                                    settingsOption(
                                        icon: "doc.on.doc",
                                        title: "Duplizieren",
                                        action: {
                                            if let workout = viewModel.selectedWorkoutForAction {
                                                viewModel.duplicateWorkout(workout)
                                                viewModel.hideFABOptions()
                                            }
                                        }
                                    )
                                    
                                    settingsOption(
                                        icon: "pencil",
                                        title: "Umbenennen",
                                        action: {
                                            if let workout = viewModel.selectedWorkoutForAction {
                                                viewModel.showRenameWorkout(for: workout)
                                            }
                                        }
                                    )
                                    
                                    if let workout = viewModel.selectedWorkoutForAction {
                                        if viewModel.isDefaultWorkout(workout) {
                                            settingsOption(
                                                icon: "star.slash",
                                                title: "Remove as Default",
                                                action: {
                                                    viewModel.removeAsDefault()
                                                    viewModel.hideFABOptions()
                                                }
                                            )
                                        } else {
                                            settingsOption(
                                                icon: "star",
                                                title: "Set as Default",
                                                action: {
                                                    viewModel.setAsDefault(workout)
                                                    viewModel.hideFABOptions()
                                                }
                                            )
                                        }
                                    }
                                    
                                    if viewModel.canDeleteWorkout {
                                        settingsOption(
                                            icon: "trash",
                                            title: "Löschen",
                                            isDestructive: true,
                                            action: {
                                                viewModel.showDeleteConfirmation()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .background(AppStyle.Color.greenDark)
                        .cornerRadius(16)
                        .padding(.horizontal, 32)
                        .padding(.bottom, safeAreaInset + 16)
                        .padding(.top, 16)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.3), value: viewModel.showingFABOptions)
            }
        }
    }
    
    private func settingsOption(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppStyle.Color.greenGlow)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
    }
    
    private var safeAreaInset: CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

private struct WorkoutTileView: View {
    let workout: Workout
    let isDefault: Bool
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
                
                Spacer()
                
                // Workout Name zentriert
                VStack(spacing: 4) {
                    Text(workout.name)
                        .font(AppStyle.Font.categorySelectionNameFont)
                        .foregroundColor(AppStyle.Color.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(formattedDate(workout.lastModified))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#46474B"))
                        .multilineTextAlignment(.center)
                }
                
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
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 
