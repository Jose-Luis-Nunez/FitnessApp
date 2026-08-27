import FitnessCore
import FitnessTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessAnalytics
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
private func fixedWorkoutDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter
}

@Suite("Workout analytics entry — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct WorkoutAnalyticsEntrySnapshotTests {
    @Test(
        "Workout entry stays readable at the narrow supported width",
        arguments: [CGFloat(320)]
    )
    func layout(width: CGFloat) throws {
        let workout = Workout(name: "Push Day")
        let exercises = [
            makeExercise(
                name: "Bench Press",
                weight: 80,
                reps: 8,
                sets: 3,
                category: .chest
            ),
            makeExercise(
                name: "Incline Press",
                weight: 32,
                reps: 10,
                sets: 3,
                category: .chest
            ),
            makeExercise(
                name: "Bodyweight Dips",
                weight: 0,
                reps: 12,
                sets: 3,
                category: .arms
            ),
            makeExercise(
                name: "Long Shoulder Press Name",
                weight: 24,
                reps: 10,
                sets: 3,
                category: .arms
            ),
        ]
        let exerciseStorage = MockExerciseStorage()
        exerciseStorage.exercisesByCategory = Dictionary(
            grouping: exercises,
            by: \.category
        )
        let analyticsStorage = MockAnalyticsStorage()
        let viewModel = WorkoutAnalyticsEntryViewModel(
            workout: workout,
            selectedDate: Date(timeIntervalSince1970: 1_775_203_200),
            exerciseStorage: exerciseStorage,
            saveUseCase: SaveWorkoutAnalyticsUseCase(
                batchStorage: analyticsStorage
            )
        )
        viewModel.toggleSelection(for: exercises[1].id)
        let armsIcon = try appAssetImage(named: "defaultArmsIcon")
        let chestIcon = try appAssetImage(named: "defaultChestIcon")
        let iconsByCategory: [MuscleCategoryGroup: Image] = [
            .arms: armsIcon,
            .chest: chestIcon,
        ]

        let size = CGSize(width: width, height: 720)
        let view = WorkoutAnalyticsEntryView(
            viewModel: viewModel,
            isPresented: .constant(true),
            headerDateFormatter: fixedWorkoutDateFormatter(),
            exerciseIconProvider: { exercise, _ in
                iconsByCategory[exercise.category] ?? armsIcon
            }
        )
        .appColorTheme(.green)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(
            \.safeAreaInsets,
            EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 0)
        )
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "en_US"))
        .frame(width: size.width, height: size.height)
        .background(AppStyle.Color.backgroundColor)

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .wait(
                for: 0.25,
                on: .image(
                    // 0.999 rather than 0.99: the looser budget let a stale
                    // baseline pass after a 1pt geometry shift, because that
                    // moves well under 1% of the pixels. `perceptualPrecision`
                    // stays at 0.98 to absorb antialiasing noise.
                    precision: 0.999,
                    perceptualPrecision: 0.98,
                    size: size
                )
            ),
            named: "workout-entry-\(Int(width))",
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : nil
        )
    }
}
#endif
