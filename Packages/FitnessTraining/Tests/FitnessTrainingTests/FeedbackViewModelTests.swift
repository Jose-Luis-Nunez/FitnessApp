import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import FitnessStorage
import Factory

@Suite("FeedbackViewModel")
@MainActor
struct FeedbackViewModelTests {

    init() {
        Container.shared.reset()
    }

    @Test func initialPainCategoryMatchesExerciseMuscleGroup() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .legs)
        #expect(vm.painCategory == .legs)
    }

    @Test func initialPainRegionsIsEmpty() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .arms)
        #expect(vm.painRegions.isEmpty)
    }

    @Test func togglePainRegionAddsAndRemoves() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions.contains(.lowerBack))
        vm.togglePainRegion(.upperBack)
        #expect(vm.painRegions == [.lowerBack, .upperBack])
        vm.togglePainRegion(.lowerBack)
        #expect(vm.painRegions == [.upperBack])
    }

    @Test func setEnergyLevelPersistsValue() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .chest)
        vm.energyLevel = 3
        #expect(vm.energyLevel == 3)
        vm.energyLevel = nil
        #expect(vm.energyLevel == nil)
    }

    @Test func toggleSymptomAddsAndRemoves() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain))
        vm.toggleSymptom(.pain)
        #expect(vm.symptoms.contains(.pain) == false)
    }

    @Test func isSaveEnabledRequiresAtLeastOneField() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.painRegions = []
        vm.note = ""
        #expect(vm.isSaveEnabled == false)

        vm.energyLevel = 2
        #expect(vm.isSaveEnabled == true)
    }

    @Test func isSaveEnabledTrueWhenOnlyPainRegionSelected() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.togglePainRegion(.lowerBack)
        #expect(vm.isSaveEnabled == true)
    }

    @Test func saveSkipsWhenEmpty() {
        let vm = FeedbackViewModel(exerciseId: UUID())
        vm.painRegions = []
        vm.note = ""
        vm.symptoms = []

        #expect(vm.save() == nil)
    }

    @Test func saveReturnsPersistedFeedback() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.energyLevel = 3
        vm.toggleSymptom(.pain)
        vm.togglePainRegion(.lowerBack)
        vm.togglePainRegion(.upperBack)
        vm.note = "  pain from set 2  "

        let saved = vm.save()
        #expect(saved != nil)
        #expect(saved?.energyLevel == 3)
        #expect(saved?.symptoms == [.pain])
        #expect(saved?.painRegions == [.lowerBack, .upperBack])
        #expect(saved?.painCategory == .back)
        #expect(saved?.note == "pain from set 2")
    }

    @Test func saveWithoutPainRegionsDoesNotSetPainCategory() {
        let vm = FeedbackViewModel(exerciseId: UUID(), exerciseCategory: .back)
        vm.energyLevel = 4

        let saved = vm.save()
        #expect(saved != nil)
        #expect(saved?.painRegions.isEmpty == true)
        #expect(saved?.painCategory == nil)
    }
}
