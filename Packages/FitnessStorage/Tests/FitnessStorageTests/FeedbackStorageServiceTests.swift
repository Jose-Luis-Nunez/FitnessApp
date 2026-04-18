import Testing
import Foundation
import SwiftData
import FitnessCore
@testable import FitnessStorage
import Factory

@Suite("FeedbackStorageService")
@MainActor
struct FeedbackStorageServiceTests {

    private let container: ModelContainer

    init() {
        container = TestHelpers.makeInMemoryContainer()
    }

    private func makeSUT() -> FeedbackStorageService {
        FeedbackStorageService(container: container)
    }

    @Test func saveThenLoadReturnsFeedback() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let feedback = ExerciseFeedback(
            exerciseId: exerciseId,
            energyLevel: 4,
            painCategory: .back,
            painRegions: [.lowerBack, .obliquesLeft],
            symptoms: [.pain, .muscleWeakness],
            note: "ab Satz 2 instabil"
        )

        sut.save(feedback)
        let loaded = sut.load(for: exerciseId)

        #expect(loaded.count == 1)
        let entry = loaded.first!
        #expect(entry.exerciseId == exerciseId)
        #expect(entry.energyLevel == 4)
        #expect(entry.painRegions == [.lowerBack, .obliquesLeft])
        #expect(entry.painCategory == .back)
        #expect(entry.symptoms == [.pain, .muscleWeakness])
        #expect(entry.note == "ab Satz 2 instabil")
    }

    @Test func multipleRegionsRoundtripThroughStorage() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let allBackRegions: Set<BodyRegion> = [
            .upperBack, .middleBack, .lowerBack, .shoulderLeft, .shoulderRight
        ]

        sut.save(ExerciseFeedback(
            exerciseId: exerciseId,
            painCategory: .back,
            painRegions: allBackRegions
        ))
        let loaded = sut.latest(for: exerciseId)

        #expect(loaded?.painRegions == allBackRegions)
    }

    @Test func loadIsEmptyWhenNothingSaved() {
        let sut = makeSUT()
        #expect(sut.load(for: UUID()).isEmpty)
    }

    @Test func savingMultipleEntriesPreservesThemSortedByDate() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let calendar = Calendar.current
        let day1 = calendar.date(byAdding: .day, value: -2, to: Date())!
        let day2 = calendar.date(byAdding: .day, value: -1, to: Date())!
        let day3 = Date()

        sut.save(ExerciseFeedback(exerciseId: exerciseId, date: day3, energyLevel: 5))
        sut.save(ExerciseFeedback(exerciseId: exerciseId, date: day1, energyLevel: 1))
        sut.save(ExerciseFeedback(exerciseId: exerciseId, date: day2, energyLevel: 3))

        let loaded = sut.load(for: exerciseId)
        #expect(loaded.count == 3)
        #expect(loaded[0].date <= loaded[1].date)
        #expect(loaded[1].date <= loaded[2].date)
        #expect(loaded.last?.energyLevel == 5)
    }

    @Test func latestReturnsMostRecentFeedback() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let calendar = Calendar.current

        sut.save(ExerciseFeedback(
            exerciseId: exerciseId,
            date: calendar.date(byAdding: .day, value: -1, to: Date())!,
            energyLevel: 2
        ))
        sut.save(ExerciseFeedback(
            exerciseId: exerciseId,
            date: Date(),
            energyLevel: 4
        ))

        #expect(sut.latest(for: exerciseId)?.energyLevel == 4)
    }

    @Test func isolationBetweenExercises() {
        let sut = makeSUT()
        let id1 = UUID()
        let id2 = UUID()

        sut.save(ExerciseFeedback(exerciseId: id1, energyLevel: 3))
        sut.save(ExerciseFeedback(exerciseId: id2, energyLevel: 5))

        #expect(sut.load(for: id1).count == 1)
        #expect(sut.load(for: id2).count == 1)
        #expect(sut.load(for: UUID()).isEmpty)
    }

    @Test func symptomsRoundtripThroughStorage() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let allSymptoms: Set<Symptom> = [.pain, .dizziness, .nausea, .muscleWeakness]

        sut.save(ExerciseFeedback(exerciseId: exerciseId, symptoms: allSymptoms))
        let loaded = sut.latest(for: exerciseId)

        #expect(loaded?.symptoms == allSymptoms)
    }
}
