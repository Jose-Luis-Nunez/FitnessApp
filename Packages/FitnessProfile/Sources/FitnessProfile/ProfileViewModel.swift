import Foundation
import SwiftUI

/// Isolates UserDefaults persistence from `@Observable` state so that
/// reads/writes don't trigger observation on every keystroke.
@MainActor
public final class ProfileStore {
    @AppStorage("userNickname") public var nickname: String = ""
    @AppStorage("userWeight") public var weightKg: Double = 0
    @AppStorage("userHeight") public var heightCm: Double = 0
    @AppStorage("userAge") public var age: Int = 0

    public init() {}
}

@Observable
@MainActor
public final class ProfileViewModel {
    public let store = ProfileStore()
    public let tramVM = TramDeparturesViewModel()

    public var nickname: String = ""
    public var weightKg: Double = 0
    public var heightCm: Double = 0
    public var age: Int = 0

    public var inputNickname: String = ""

    /// Typed drafts used by the body-data wheel pickers. Kept locale-agnostic
    /// (no String formatting in the binding path) so the UI can reuse a
    /// generic typed wheel picker and the ViewModel can persist without
    /// re-parsing.
    public var draftWeightKg: Double = 75
    public var draftHeightCm: Int = 175
    public var draftAge: Int = 30

    /// Neutral defaults seeded when the user has no body data yet.
    public static let defaultDraftWeightKg: Double = 75
    public static let defaultDraftHeightCm: Int = 175
    public static let defaultDraftAge: Int = 30

    public var isEditingNickname = false
    public var isEditingBody = false
    public var showNicknameAlert = false

    public var bmiResult: BMIResult?
    public var isLoadingBMI = false
    public var bmiError: String?

    private let bmiService: BMIServicing
    private var bmiTask: Task<Void, Never>?

    public init(bmiService: BMIServicing? = nil) {
        self.bmiService = bmiService ?? BMIService()
        nickname = store.nickname
        weightKg = store.weightKg
        heightCm = store.heightCm
        age = store.age
    }

    public var hasProfile: Bool {
        !nickname.isEmpty
    }

    public var hasBodyData: Bool {
        weightKg > 0 && heightCm > 0 && age > 0
    }

    public var heightM: Double {
        heightCm / 100.0
    }

    public var formattedBMI: String {
        guard let bmi = bmiResult else { return "–" }
        return String(format: "%.1f", bmi.value)
    }

    public var isNicknameInputEmpty: Bool {
        inputNickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func startEditingNickname() {
        inputNickname = nickname
        isEditingNickname = true
    }

    public func saveNickname() {
        let trimmed = inputNickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showNicknameAlert = true
            return
        }
        nickname = trimmed
        store.nickname = trimmed
        inputNickname = ""
        isEditingNickname = false
    }

    public func cancelNicknameEdit() {
        inputNickname = ""
        isEditingNickname = false
    }

    public func startEditingBody() {
        draftWeightKg = weightKg > 0 ? weightKg : Self.defaultDraftWeightKg
        draftHeightCm = heightCm > 0 ? Int(heightCm.rounded()) : Self.defaultDraftHeightCm
        draftAge = age > 0 ? age : Self.defaultDraftAge
        isEditingBody = true
    }

    public func saveBodyData() {
        weightKg = draftWeightKg
        store.weightKg = draftWeightKg

        heightCm = Double(draftHeightCm)
        store.heightCm = Double(draftHeightCm)

        age = draftAge
        store.age = draftAge

        isEditingBody = false
        fetchBMI()
    }

    public func cancelBodyEdit() {
        isEditingBody = false
    }

    public func fetchBMI() {
        guard weightKg > 0, heightCm > 0 else { return }

        bmiTask?.cancel()

        isLoadingBMI = true
        bmiError = nil

        let weight = weightKg
        let height = heightM

        bmiTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.bmiService.fetchBMI(weightKg: weight, heightM: height)
                if Task.isCancelled { return }
                self.bmiResult = result
                self.bmiError = nil
            } catch {
                if Task.isCancelled { return }
                if let local = self.bmiService.calculateBMILocally(weightKg: weight, heightM: height) {
                    self.bmiResult = local
                    self.bmiError = "Offline – using local calculation."
                } else {
                    self.bmiError = "Could not calculate BMI."
                }
            }
            if Task.isCancelled { return }
            self.isLoadingBMI = false
        }
    }

    public func loadInitialBMI() {
        if hasBodyData, bmiResult == nil {
            fetchBMI()
        }
    }
}
