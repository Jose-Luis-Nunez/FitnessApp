import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import FitnessCore
import FitnessTestSupport
import FitnessTraining
@testable import FitnessExercise

@Suite("ExercisePickerView", .tags(.integration))
@MainActor
struct ExercisePickerViewTests {

    @Test func newExerciseSelectsSeatSettingsByDefault() {
        let formViewModel = ExerciseFormViewModel()
        formViewModel.noSeats = true
        let categoryViewModel = MuscleCategoryViewModel(
            group: .arms,
            exercises: [],
            storageService: MockExerciseStorage(),
            workoutStorageService: MockWorkoutStorage(),
            activeSetViewModel: ActiveSetViewModel()
        )
        let view = ExercisePickerView(
            formViewModel: formViewModel,
            isPresented: .constant(true),
            onSave: {},
            onCancel: {},
            repsRange: 1...30,
            weightOptions: [20],
            setsRange: 1...10,
            viewModel: categoryViewModel,
            editingExercise: nil
        )

        #if canImport(UIKit)
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.view.layoutIfNeeded()
        #elseif canImport(AppKit)
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.makeKeyAndOrderFront(nil)
        host.view.layoutSubtreeIfNeeded()
        #endif

        #expect(formViewModel.noSeats == false)
    }
}
