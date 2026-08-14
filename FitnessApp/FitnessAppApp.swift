import SwiftUI
import SwiftData
import UIKit
import FitnessCore
import FitnessStorage
import FitnessUI
import FitnessExercise
import FitnessAnalytics
import FitnessSchedule
import FitnessTraining
import FitnessWorkouts
import FitnessFriends
import FitnessResources
import Factory

@main
struct FitnessAppApp: App {
    private let launchStrategy: any AppLaunchStrategy
    private let modelContainer: ModelContainer

    @State private var router = AppRouter()
    @State private var overlayState = UIOverlayState()
    @State private var workoutStorageService: WorkoutStorageService
    @State private var didLaunch: Bool = false
    /// Presentation state belongs to the scene-level owner so the selected
    /// List/Overview mode survives recreation of the `.home` destination.
    @State private var categorySelectionViewMode: MuscleCategorySelectionViewMode = .overview
    /// Sole persistence owner for the app-wide accent preference. The stored
    /// key and raw values remain compatible with existing installations.
    @AppStorage(AppAccentScheme.storageKey) private var accentScheme: AppAccentScheme = .green
    @AppStorage(AppLanguage.storageKey) private var appLanguage: AppLanguage = .english

    init() {
        let textFieldAppearance = UITextField.appearance()
        textFieldAppearance.layer.shadowOpacity = 0
        textFieldAppearance.layer.shadowRadius = 0
        textFieldAppearance.backgroundColor = .clear

        // Resolve the container first; ModelContainerBootstrap runs the
        // JSON → SwiftData import inside `makeProductionContainer()` so that
        // any subsequent service resolution sees the post-migration state.
        // The `WorkoutStorageService` initialiser MUST run after this — pulling
        // it onto a `@State` default expression would resolve it as a
        // stored-property default (i.e. before `init()`), which is exactly the
        // legacy-import startup race that caused pre-fix installs to fall back
        // to an empty auto-"Workout 1".
        let container = Container.shared.modelContainer()
        self.modelContainer = container

        guard let concreteStorage = Container.shared.workoutStorage() as? WorkoutStorageService else {
            preconditionFailure("Container.workoutStorage must resolve to WorkoutStorageService")
        }
        _workoutStorageService = State(wrappedValue: concreteStorage)

        #if UITESTING
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let config = UITestLaunchConfig.from(
               environment: ProcessInfo.processInfo.environment
           ) {
            launchStrategy = UITestLaunchStrategy(config: config)
        } else {
            launchStrategy = ProductionLaunchStrategy()
        }
        #else
        launchStrategy = ProductionLaunchStrategy()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            GeometryReader { geo in
            ZStack(alignment: .bottom) {
                @Bindable var routerBindable = router
                NavigationStack(path: $routerBindable.path) {
                    WorkoutsScreen()
                        .onAppear {
                            guard !didLaunch, router.isEmpty else { return }
                            launchStrategy.prepare(workoutService: workoutStorageService)
                            launchStrategy.configureEnvironment()
                            let stack = launchStrategy.initialNavigationStack(
                                workoutService: workoutStorageService
                            )
                            if !stack.isEmpty {
                                router.replaceAll(with: stack)
                            }
                            didLaunch = true
                        }
                    .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            let view = Group {
                                switch destination {
                                case .home:
                                    MuscleCategorySelectionView(
                                        viewMode: $categorySelectionViewMode
                                    )
                                        .navigationBarBackButtonHidden(true)
                                case .profile:
                                    ProfileView(
                                        accentScheme: $accentScheme,
                                        appLanguage: $appLanguage
                                    )
                                        .navigationBarBackButtonHidden(true)
                                case .totalAnalytics:
                                    TotalAnalyticsView()
                                        .navigationBarBackButtonHidden(true)
                                case .schedule:
                                    ScheduleView()
                                        .navigationBarBackButtonHidden(true)
                                case .muscleCategory(let group):
                                    MuscleCategoryView(group: group)
                                        .navigationBarBackButtonHidden(true)
                                }
                            }
                            // Workout selection and muscle categories are
                            // drill-downs. Training is a separate sheet
                            // presentation and never mutates this stack.
                            switch destination {
                            case .home where router.isHomePushedFromWorkoutList:
                                view.enableSwipeBack()
                            case .muscleCategory:
                                view.enableSwipeBack()
                            case .home, .profile, .totalAnalytics, .schedule:
                                view
                            }
                        }
                }
                .zIndex(
                    overlayState.isEditingSheetVisible && router.trainingPresentation == nil
                        ? 2
                        : 0
                )

                if let presentation = router.trainingPresentation {
                    TrainingSheetView(
                        exerciseId: presentation.exerciseId,
                        category: presentation.category
                    )
                    .id(presentation.id)
                    .zIndex(overlayState.isEditingSheetVisible ? 3 : 0.5)
                }

                let showBack = !router.isEmpty
                    || router.trainingPresentation != nil

                BottomMenuBarView(
                    showBackButton: showBack,
                    narrowBy: 74,
                    onRightAction: {
                        if router.trainingPresentation != nil {
                            overlayState.showTrainingMiniMenu.toggle()
                            return
                        }
                        switch router.currentScene {
                        case .home:
                            overlayState.showSelectionMiniMenu.toggle()
                        case .category:
                            overlayState.showCategoryMiniMenu.toggle()
                        case .workouts:
                            overlayState.showWorkoutsMiniMenu.toggle()
                        case .profile, .schedule, .analytics:
                            // Unreachable: the ellipsis button is hidden on these
                            // scenes (see BottomMenuBarView.showsRightAction). Kept
                            // for switch exhaustiveness over the scene enum.
                            break
                        }
                    },
                    onTrainingTab: {
                        router.dismissTraining()
                        // Quick-launch the default workout, or prompt the user to
                        // pick one when none is set yet.
                        if let workout = workoutStorageService.defaultWorkout {
                            workoutStorageService.setCurrentWorkout(workout)
                            router.replaceAll(with: [.home])
                        } else if !workoutStorageService.workouts.isEmpty {
                            overlayState.showDefaultWorkoutPicker = true
                        } else {
                            // No workouts at all — send the user to the list to create one.
                            router.popToRoot()
                        }
                    },
                    customBackAction: router.trainingPresentation != nil ? {
                        router.dismissTraining()
                    } : nil
                )
                .zIndex(Self.shouldHideBottomBar(overlayState) ? 0 : 1)
                .opacity(Self.shouldHideBottomBar(overlayState) ? 0 : 1)
                .allowsHitTesting(!Self.shouldHideBottomBar(overlayState))

                if overlayState.showDefaultWorkoutPicker {
                    DefaultWorkoutPickerOverlay(
                        workouts: workoutStorageService.workouts,
                        onPick: { workout in
                            workoutStorageService.setAsDefaultWorkout(workout)
                            workoutStorageService.setCurrentWorkout(workout)
                            overlayState.showDefaultWorkoutPicker = false
                            router.replaceAll(with: [.home])
                        },
                        onDismiss: { overlayState.showDefaultWorkoutPicker = false }
                    )
                    .zIndex(3)
                }
            }
            // Environment propagation re-renders color consumers without
            // replacing view identity or resetting feature-owned state.
            .appColorTheme(accentScheme)
            .environment(\.locale, appLanguage.locale)
            .environment(\.safeAreaInsets, geo.safeAreaInsets)
            .environment(overlayState)
            .environment(router)
            .onOpenURL { url in
                let ext = url.pathExtension.lowercased()
                if ext == "fitnessfriend" {
                    Container.shared.friendImportCoordinator().handleIncomingFile(url)
                    router.switchToProfile()
                } else {
                    // `.fitnessworkout` and any other file types → workout import flow.
                    // Pop nav stack so the user lands on the Workouts root when the sheet opens.
                    router.popToRoot()
                    Container.shared.workoutImportCoordinator().handleIncomingFile(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                overlayState.isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                overlayState.isKeyboardVisible = false
            }
            }
            .modelContainer(modelContainer)
        }
    }

    /// Hide the glass bottom bar when any blocking overlay is up, or when
    /// the system keyboard is visible — otherwise the bar sits right above
    /// the keyboard and visually competes with the input field.
    private static func shouldHideBottomBar(_ state: UIOverlayState) -> Bool {
        state.isEditingSheetVisible
            || state.showCategoryMiniMenu
            || state.showSelectionMiniMenu
            || state.showWorkoutsMiniMenu
            || state.showWorkoutSettingsMenu
            || state.showTrainingMiniMenu
            || state.showDefaultWorkoutPicker
            || state.isKeyboardVisible
    }
}
