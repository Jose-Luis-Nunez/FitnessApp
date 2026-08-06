import Foundation
import SwiftUI
import Testing
@testable import FitnessAnalytics
import FitnessCore
import FitnessTestSupport
#if canImport(UIKit)
import UIKit
#endif

@Suite("Analytics loading performance contracts", .tags(.fast))
@MainActor
struct PerformanceLoadingTests {
    @Test func detailCalculationsReuseOneLoadedHistory() throws {
        let storage = MockAnalyticsStorage()
        let exerciseId = UUID()
        let referenceDay = Calendar.current.startOfDay(for: Date())
        let entries = [
            entry(for: exerciseId, date: day(-2, from: referenceDay), reps: 8, weight: 20),
            entry(for: exerciseId, date: day(-1, from: referenceDay), reps: 8, weight: 20),
            entry(for: exerciseId, date: referenceDay, reps: 10, weight: 22),
        ]
        storage.save(entries, for: exerciseId)
        let viewModel = makeViewModel(
            storage: storage,
            exerciseStorage: MockExerciseStorage(),
            workoutStorage: MockWorkoutStorage()
        )

        #expect(viewModel.reloadEntries(for: exerciseId))
        let cachedEntries = try #require(viewModel.cachedEntries(for: exerciseId))

        #expect(viewModel.getDailyWeightProgression(from: cachedEntries).map(\.value) == [20, 20, 22])
        #expect(viewModel.getDailyRepsProgression(from: cachedEntries).map(\.value) == [8, 8, 10])
        #expect(viewModel.totalWeightIncreases(from: cachedEntries) == 1)
        #expect(viewModel.totalRepsIncreases(from: cachedEntries) == 1)
        #expect(viewModel.trainingSessionsUntilWeightIncrease(from: cachedEntries) == 2)
        #expect(viewModel.trainingSessionsUntilRepsIncrease(from: cachedEntries) == 2)
        #expect(viewModel.trainingDaysInCurrentMonth(from: cachedEntries) >= 1)

        #expect(storage.loadCallCount == 1)
        #expect(storage.batchLoadCallCount == 0)
    }

    #if canImport(UIKit)
    @Test func analyticsViewLoadsHistoryOnceAcrossRenderPasses() async {
        let storage = MockAnalyticsStorage()
        let exerciseStorage = MockExerciseStorage()
        let workoutStorage = MockWorkoutStorage()
        let exercise = FitnessTestSupport.makeExercise(category: .arms)
        exerciseStorage.exercisesByCategory[exercise.category] = [exercise]
        storage.save(
            [entry(for: exercise.id, date: Date(), reps: 10, weight: 22)],
            for: exercise.id
        )
        let viewModel = makeViewModel(
            storage: storage,
            exerciseStorage: exerciseStorage,
            workoutStorage: workoutStorage
        )
        let controller = UIHostingController(
            rootView: AnalyticsView(exercise: exercise, viewModel: viewModel)
        )
        let size = CGSize(width: 393, height: 852)
        controller.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        await Task.yield()

        #expect(storage.loadCallCount == 1)

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        await Task.yield()

        #expect(storage.loadCallCount == 1)
        #expect(storage.loadedExerciseIDs == [exercise.id])
        #expect(storage.batchLoadCallCount == 0)
    }
    #endif

    private func makeViewModel(
        storage: MockAnalyticsStorage,
        exerciseStorage: MockExerciseStorage,
        workoutStorage: MockWorkoutStorage
    ) -> AnalyticsViewModel {
        AnalyticsViewModel(
            storageService: storage,
            exerciseStorage: exerciseStorage,
            workoutStorage: workoutStorage,
            saveAnalyticsUseCase: SaveAnalyticsUseCase(analyticsStorage: storage),
            deleteAnalyticsSetUseCase: DeleteAnalyticsSetUseCase(
                analyticsStorage: storage,
                exerciseStorage: exerciseStorage,
                workoutStorage: workoutStorage
            ),
            saveOrReplaceAnalyticsUseCase: SaveOrReplaceAnalyticsUseCase(
                analyticsStorage: storage
            )
        )
    }

    private func day(_ offset: Int, from referenceDay: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: referenceDay)!
    }

    private func entry(
        for exerciseId: UUID,
        date: Date,
        reps: Int,
        weight: Double
    ) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: [
                SetProgress(status: .completedDone, currentReps: reps, weight: weight),
                SetProgress(status: .completedDone, currentReps: reps, weight: weight),
                SetProgress(status: .completedDone, currentReps: reps, weight: weight),
            ]
        )
    }
}
