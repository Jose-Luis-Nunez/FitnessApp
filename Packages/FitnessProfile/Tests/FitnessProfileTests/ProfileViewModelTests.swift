import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("ProfileViewModel Tests", .tags(.fast))
@MainActor
struct ProfileViewModelTests {

    // MARK: - Computed Properties

    @Test func hasProfile_emptyNickname_returnsFalse() {
        let vm = ProfileViewModel()
        vm.nickname = ""
        #expect(vm.hasProfile == false)
    }

    @Test func hasProfile_nonEmptyNickname_returnsTrue() {
        let vm = ProfileViewModel()
        vm.nickname = "Max"
        #expect(vm.hasProfile == true)
        vm.nickname = ""
    }

    @Test func hasBodyData_allPositive_returnsTrue() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 180
        vm.age = 28
        #expect(vm.hasBodyData == true)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func hasBodyData_zeroWeight_returnsFalse() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 180
        vm.age = 28
        #expect(vm.hasBodyData == false)
        vm.heightCm = 0; vm.age = 0
    }

    @Test func hasBodyData_zeroHeight_returnsFalse() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 0
        vm.age = 28
        #expect(vm.hasBodyData == false)
        vm.weightKg = 0; vm.age = 0
    }

    @Test func hasBodyData_zeroAge_returnsFalse() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 180
        vm.age = 0
        #expect(vm.hasBodyData == false)
        vm.weightKg = 0; vm.heightCm = 0
    }

    @Test func heightM_convertsCorrectly() {
        let vm = ProfileViewModel()
        vm.heightCm = 175
        #expect(vm.heightM == 1.75)
        vm.heightCm = 0
    }

    @Test func formattedBMI_nilResult_returnsDash() {
        let vm = ProfileViewModel()
        vm.bmiResult = nil
        #expect(vm.formattedBMI == "–")
    }

    @Test func formattedBMI_withResult_returnsOneDecimal() {
        let vm = ProfileViewModel()
        vm.bmiResult = BMIResult(value: 22.857, category: .normal)
        #expect(vm.formattedBMI == "22.9")
        vm.bmiResult = nil
    }

    // MARK: - Nickname Editing

    @Test func startEditingNickname_populatesInput() {
        let vm = ProfileViewModel()
        vm.nickname = "Max"
        vm.startEditingNickname()
        #expect(vm.inputNickname == "Max")
        #expect(vm.isEditingNickname == true)
        vm.nickname = ""
    }

    @Test func saveNickname_validInput_savesAndCloses() {
        let vm = ProfileViewModel()
        vm.inputNickname = "Lisa"
        vm.isEditingNickname = true
        vm.saveNickname()
        #expect(vm.nickname == "Lisa")
        #expect(vm.isEditingNickname == false)
        #expect(vm.inputNickname.isEmpty)
        vm.nickname = ""
    }

    @Test func saveNickname_emptyInput_showsAlert() {
        let vm = ProfileViewModel()
        vm.inputNickname = "   "
        vm.isEditingNickname = true
        vm.saveNickname()
        #expect(vm.showNicknameAlert == true)
        #expect(vm.isEditingNickname == true)
    }

    @Test func saveNickname_trimsWhitespace() {
        let vm = ProfileViewModel()
        vm.inputNickname = "  Max  "
        vm.saveNickname()
        #expect(vm.nickname == "Max")
        vm.nickname = ""
    }

    @Test func isNicknameInputEmpty_whitespaceOnly_returnsTrue() {
        let vm = ProfileViewModel()
        vm.inputNickname = "   "
        #expect(vm.isNicknameInputEmpty == true)
    }

    @Test func isNicknameInputEmpty_withText_returnsFalse() {
        let vm = ProfileViewModel()
        vm.inputNickname = "Max"
        #expect(vm.isNicknameInputEmpty == false)
    }

    @Test func cancelNicknameEdit_resetsState() {
        let vm = ProfileViewModel()
        vm.inputNickname = "Test"
        vm.isEditingNickname = true
        vm.cancelNicknameEdit()
        #expect(vm.inputNickname.isEmpty)
        #expect(vm.isEditingNickname == false)
    }

    // MARK: - Body Data Editing

    @Test func startEditingBody_populatesDrafts() {
        let vm = ProfileViewModel()
        vm.weightKg = 75.5
        vm.heightCm = 178
        vm.age = 28
        vm.startEditingBody()
        #expect(vm.draftWeightKg == 75.5)
        #expect(vm.draftHeightCm == 178)
        #expect(vm.draftAge == 28)
        #expect(vm.isEditingBody == true)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func startEditingBody_zeroValues_seedsSensibleDefaults() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 0
        vm.age = 0
        vm.startEditingBody()
        // Wheel pickers need a preselected value; the VM seeds neutral
        // defaults so the wheel lands on a sensible row instead of 0.
        #expect(vm.draftWeightKg == ProfileViewModel.defaultDraftWeightKg)
        #expect(vm.draftHeightCm == ProfileViewModel.defaultDraftHeightCm)
        #expect(vm.draftAge == ProfileViewModel.defaultDraftAge)
    }

    @Test func startEditingBody_roundsHeightToNearestInt() {
        let vm = ProfileViewModel()
        vm.weightKg = 70
        vm.heightCm = 177.6
        vm.age = 40
        vm.startEditingBody()
        #expect(vm.draftHeightCm == 178)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func saveBodyData_afterWheelSelection_persistsCorrectValues() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 0
        vm.age = 0
        vm.startEditingBody()

        vm.draftWeightKg = 82.5
        vm.draftHeightCm = 184
        vm.draftAge = 33

        vm.saveBodyData()

        #expect(vm.weightKg == 82.5)
        #expect(vm.heightCm == 184)
        #expect(vm.age == 33)
        #expect(vm.isEditingBody == false)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func saveBodyData_integerWeight_persistsExactDouble() {
        let vm = ProfileViewModel()
        vm.startEditingBody()
        vm.draftWeightKg = 75
        vm.draftHeightCm = 175
        vm.draftAge = 30
        vm.saveBodyData()
        #expect(vm.weightKg == 75.0)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func saveBodyData_unchangedBMIInputs_doesNotFetch() {
        let service = ControllableBMIService()
        let vm = ProfileViewModel(bmiService: service)
        vm.weightKg = 75
        vm.heightCm = 175
        vm.age = 30
        vm.startEditingBody()

        vm.saveBodyData()

        #expect(vm.isLoadingBMI == false)
        #expect(service.localCallCount == 0)
        #expect(service.fetchCallCount == 0)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func saveBodyData_changedBMIInputs_calculatesLocallyThenFetches() async throws {
        let localResult = BMIResult(value: 24.7, category: .normal)
        let remoteResult = BMIResult(value: 24.8, category: .normal)
        let service = ControllableBMIService(localResult: localResult)
        let vm = ProfileViewModel(bmiService: service)
        vm.weightKg = 70
        vm.heightCm = 175
        vm.age = 30
        vm.startEditingBody()
        vm.draftWeightKg = 80
        vm.draftHeightCm = 180

        vm.saveBodyData()

        #expect(vm.bmiResult?.value == localResult.value)
        #expect(vm.isLoadingBMI)
        defer { service.resume(returning: remoteResult) }
        try await service.waitUntilRequested()
        #expect(service.localCallCount == 1)
        #expect(service.fetchCallCount == 1)
        #expect(service.lastLocalWeightKg == 80)
        #expect(service.lastLocalHeightM == 1.8)
        #expect(service.lastFetchWeightKg == 80)
        #expect(service.lastFetchHeightM == 1.8)

        service.resume(returning: remoteResult)
        try await waitUntil { vm.isLoadingBMI == false }
        #expect(vm.bmiResult?.value == remoteResult.value)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0
    }

    @Test func cancelBodyEdit_closesEditMode() {
        let vm = ProfileViewModel()
        vm.isEditingBody = true
        vm.cancelBodyEdit()
        #expect(vm.isEditingBody == false)
    }

    // MARK: - Fetch BMI Guards

    @Test func fetchBMI_zeroWeight_doesNotLoad() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 180
        vm.fetchBMI()
        #expect(vm.isLoadingBMI == false)
    }

    @Test func fetchBMI_zeroHeight_doesNotLoad() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 0
        vm.fetchBMI()
        #expect(vm.isLoadingBMI == false)
    }

    // MARK: - Local BMI Load

    @Test func loadBMIIfNeeded_noBodyData_doesNotFetch() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 0
        vm.age = 0
        vm.bmiResult = nil
        vm.loadBMIIfNeeded()
        #expect(vm.isLoadingBMI == false)
        #expect(vm.bmiResult == nil)
    }

    @Test func loadBMIIfNeeded_existingResult_doesNotRefetch() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 180
        vm.age = 28
        vm.bmiResult = BMIResult(value: 23.1, category: .normal)
        vm.loadBMIIfNeeded()
        #expect(vm.isLoadingBMI == false)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0; vm.bmiResult = nil
    }

    @Test func loadBMIIfNeeded_populatesLocalResultWithoutFetching() {
        let service = ControllableBMIService()
        let vm = ProfileViewModel(bmiService: service)
        vm.weightKg = 75
        vm.heightCm = 180
        vm.age = 28
        vm.bmiResult = nil
        vm.loadBMIIfNeeded()

        #expect(vm.bmiResult != nil)
        #expect(vm.isLoadingBMI == false)
        #expect(service.localCallCount == 1)
        #expect(service.fetchCallCount == 0)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0; vm.bmiResult = nil
    }

    private final class ControllableBMIService: BMIServicing, @unchecked Sendable {
        private let lock = NSLock()
        private let localResult: BMIResult
        private var continuation: CheckedContinuation<BMIResult, Error>?
        private var storedLocalCallCount = 0
        private var storedFetchCallCount = 0
        private var storedLastLocalWeightKg: Double?
        private var storedLastLocalHeightM: Double?
        private var storedLastFetchWeightKg: Double?
        private var storedLastFetchHeightM: Double?

        init(localResult: BMIResult = BMIResult(value: 23.1, category: .normal)) {
            self.localResult = localResult
        }

        var localCallCount: Int {
            lock.withLock { storedLocalCallCount }
        }

        var fetchCallCount: Int {
            lock.withLock { storedFetchCallCount }
        }

        var lastLocalWeightKg: Double? {
            lock.withLock { storedLastLocalWeightKg }
        }

        var lastLocalHeightM: Double? {
            lock.withLock { storedLastLocalHeightM }
        }

        var lastFetchWeightKg: Double? {
            lock.withLock { storedLastFetchWeightKg }
        }

        var lastFetchHeightM: Double? {
            lock.withLock { storedLastFetchHeightM }
        }

        func calculateBMILocally(weightKg: Double, heightM: Double) -> BMIResult? {
            lock.withLock {
                storedLocalCallCount += 1
                storedLastLocalWeightKg = weightKg
                storedLastLocalHeightM = heightM
            }
            return localResult
        }

        func fetchBMI(weightKg: Double, heightM: Double) async throws -> BMIResult {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    storedFetchCallCount += 1
                    storedLastFetchWeightKg = weightKg
                    storedLastFetchHeightM = heightM
                    self.continuation = continuation
                }
            }
        }

        func waitUntilRequested() async throws {
            try await waitUntil { self.fetchCallCount == 1 }
        }

        func resume(returning result: BMIResult) {
            let pending = lock.withLock {
                let pending = continuation
                continuation = nil
                return pending
            }
            pending?.resume(returning: result)
        }
    }
}
