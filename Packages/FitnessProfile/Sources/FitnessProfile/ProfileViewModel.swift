import Foundation
import SwiftUI
import FitnessUI

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

    public var nickname: String = ""
    public var weightKg: Double = 0
    public var heightCm: Double = 0
    public var age: Int = 0

    public var inputNickname: String = ""
    public var inputWeight: String = ""
    public var inputHeight: String = ""
    public var inputAge: String = ""

    public var isEditingNickname = false
    public var isEditingBody = false
    public var showNicknameAlert = false

    public var bmiResult: BMIResult?
    public var isLoadingBMI = false
    public var bmiError: String?

    private let bmiService = BMIService()

    public init() {
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
        inputWeight = weightKg > 0 ? WeightFormatter.format(weightKg) : ""
        inputHeight = heightCm > 0 ? String(format: "%.0f", heightCm) : ""
        inputAge = age > 0 ? "\(age)" : ""
        isEditingBody = true
    }

    public func saveBodyData() {
        if let w = WeightFormatter.parse(inputWeight) {
            weightKg = w
            store.weightKg = w
        }
        if let h = WeightFormatter.parse(inputHeight) {
            heightCm = h
            store.heightCm = h
        }
        if let a = Int(inputAge) {
            age = a
            store.age = a
        }
        isEditingBody = false
        fetchBMI()
    }

    public func cancelBodyEdit() {
        isEditingBody = false
    }

    public func fetchBMI() {
        guard weightKg > 0, heightCm > 0 else { return }

        isLoadingBMI = true
        bmiError = nil

        Task {
            do {
                let result = try await bmiService.fetchBMI(weightKg: weightKg, heightM: heightM)
                bmiResult = result
                bmiError = nil
            } catch {
                if let local = bmiService.calculateBMILocally(weightKg: weightKg, heightM: heightM) {
                    bmiResult = local
                }
                bmiError = "API nicht erreichbar – lokale Berechnung verwendet."
            }
            isLoadingBMI = false
        }
    }

    public func loadInitialBMI() {
        if hasBodyData, bmiResult == nil {
            fetchBMI()
        }
    }
}
