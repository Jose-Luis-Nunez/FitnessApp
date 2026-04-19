import Testing
import Foundation
import SwiftData
import FitnessCore
@_spi(PersistenceUI) @testable import FitnessStorage
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

    // MARK: - Upsert by session id

    @Test func saveInsertsWhenSessionIsNew() {
        let sut = makeSUT()
        let exerciseId = UUID()

        sut.save(ExerciseFeedback(exerciseId: exerciseId, energyLevel: 3))

        #expect(sut.load(for: exerciseId).count == 1)
    }

    @Test func saveUpdatesInPlaceWhenSessionAlreadyExists() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let sessionId = UUID()

        sut.save(ExerciseFeedback(
            sessionId: sessionId, exerciseId: exerciseId, energyLevel: 1
        ))
        sut.save(ExerciseFeedback(
            sessionId: sessionId, exerciseId: exerciseId, energyLevel: 5
        ))

        let loaded = sut.load(for: exerciseId)
        #expect(loaded.count == 1)
        #expect(loaded.first?.energyLevel == 5)
        #expect(loaded.first?.sessionId == sessionId)
    }

    @Test func saveUpdatedRecordReplacesAllFields() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let sessionId = UUID()

        sut.save(ExerciseFeedback(
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 1,
            painCategory: .back,
            painRegions: [.lowerBack],
            symptoms: [.pain],
            note: "first"
        ))
        sut.save(ExerciseFeedback(
            sessionId: sessionId,
            exerciseId: exerciseId,
            energyLevel: 4,
            painCategory: nil,
            painRegions: [],
            symptoms: [.dizziness, .nausea],
            note: "second"
        ))

        let loaded = sut.latest(for: exerciseId)
        #expect(loaded?.energyLevel == 4)
        #expect(loaded?.painCategory == nil)
        #expect(loaded?.painRegions.isEmpty == true)
        #expect(loaded?.symptoms == [.dizziness, .nausea])
        #expect(loaded?.note == "second")
    }

    @Test func twoDifferentSessionsForSameExerciseKeepBothRows() {
        // Two sessions of the same exercise (e.g. started, finished, then
        // started again on the same day) must produce two records — analogous
        // to analytics that keep one row per completed session.
        let sut = makeSUT()
        let exerciseId = UUID()

        sut.save(ExerciseFeedback(
            sessionId: UUID(), exerciseId: exerciseId, energyLevel: 2
        ))
        sut.save(ExerciseFeedback(
            sessionId: UUID(), exerciseId: exerciseId, energyLevel: 4
        ))

        #expect(sut.load(for: exerciseId).count == 2)
    }

    @Test func twoSessionsOnSameDayBothPersist() {
        let sut = makeSUT()
        let exerciseId = UUID()
        let sameDay = Date()

        sut.save(ExerciseFeedback(
            sessionId: UUID(), exerciseId: exerciseId, date: sameDay, energyLevel: 1
        ))
        sut.save(ExerciseFeedback(
            sessionId: UUID(), exerciseId: exerciseId, date: sameDay, energyLevel: 5
        ))

        let loaded = sut.load(for: exerciseId)
        #expect(loaded.count == 2)
        #expect(Set(loaded.map(\.energyLevel)) == [1, 5])
    }
}
