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

    // MARK: - Load Initial BMI

    @Test func loadInitialBMI_noBodyData_doesNotFetch() {
        let vm = ProfileViewModel()
        vm.weightKg = 0
        vm.heightCm = 0
        vm.age = 0
        vm.bmiResult = nil
        vm.loadInitialBMI()
        #expect(vm.isLoadingBMI == false)
    }

    @Test func loadInitialBMI_existingResult_doesNotRefetch() {
        let vm = ProfileViewModel()
        vm.weightKg = 75
        vm.heightCm = 180
        vm.age = 28
        vm.bmiResult = BMIResult(value: 23.1, category: .normal)
        vm.loadInitialBMI()
        #expect(vm.isLoadingBMI == false)
        vm.weightKg = 0; vm.heightCm = 0; vm.age = 0; vm.bmiResult = nil
    }
}
