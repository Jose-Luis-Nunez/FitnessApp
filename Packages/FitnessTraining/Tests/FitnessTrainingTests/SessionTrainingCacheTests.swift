import Testing
import Foundation
@testable import FitnessTraining
import FitnessCore
import Factory

@Suite("SessionTrainingCache")
@MainActor
struct SessionTrainingCacheTests {

    @Test func returnsSameInstanceForSameGroup() {
        let cache = SessionTrainingCache()

        let first = cache.viewModel(for: .arms)
        let second = cache.viewModel(for: .arms)

        #expect(first === second)
    }

    @Test func returnsNewInstanceForDifferentGroup() {
        let cache = SessionTrainingCache()

        let arms = cache.viewModel(for: .arms)
        let chest = cache.viewModel(for: .chest)

        #expect(arms !== chest)
    }

    @Test func storesInActiveSetVMsDictionary() {
        let cache = SessionTrainingCache()
        #expect(cache.activeSetVMs.isEmpty)

        _ = cache.viewModel(for: .legs)

        #expect(cache.activeSetVMs.count == 1)
        #expect(cache.activeSetVMs[.legs] != nil)
    }

    @Test func eachGroupGetsItsOwnInstance() {
        let cache = SessionTrainingCache()

        for group in MuscleCategoryGroup.allCases {
            _ = cache.viewModel(for: group)
        }

        #expect(cache.activeSetVMs.count == MuscleCategoryGroup.allCases.count)

        let uniqueInstances = Set(cache.activeSetVMs.values.map { ObjectIdentifier($0) })
        #expect(uniqueInstances.count == MuscleCategoryGroup.allCases.count)
    }
}
