import Foundation
import SwiftUI
import FitnessUI

/// Isolates UserDefaults persistence from `@Published` state so that
/// reads/writes don't trigger `objectWillChange` on every keystroke.
@MainActor
final class ProfileStore {
    @AppStorage("userNickname") var nickname: String = ""
    @AppStorage("userWeight") var weightKg: Double = 0
    @AppStorage("userHeight") var heightCm: Double = 0
    @AppStorage("userAge") var age: Int = 0
}

@MainActor
final class ProfileViewModel: ObservableObject {
    let store = ProfileStore()

    @Published var nickname: String = ""
    @Published var weightKg: Double = 0
    @Published var heightCm: Double = 0
    @Published var age: Int = 0

    @Published var inputNickname: String = ""
    @Published var inputWeight: String = ""
    @Published var inputHeight: String = ""
    @Published var inputAge: String = ""

    @Published var isEditingNickname = false
    @Published var isEditingBody = false
    @Published var showNicknameAlert = false

    @Published var bmiResult: BMIResult?
    @Published var isLoadingBMI = false
    @Published var bmiError: String?

    private let bmiService = BMIService()

    init() {
        nickname = store.nickname
        weightKg = store.weightKg
        heightCm = store.heightCm
        age = store.age
    }

    var hasProfile: Bool {
        !nickname.isEmpty
    }

    var hasBodyData: Bool {
        weightKg > 0 && heightCm > 0 && age > 0
    }

    var heightM: Double {
        heightCm / 100.0
    }

    var formattedBMI: String {
        guard let bmi = bmiResult else { return "–" }
        return String(format: "%.1f", bmi.value)
    }

    var isNicknameInputEmpty: Bool {
        inputNickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func startEditingNickname() {
        inputNickname = nickname
        isEditingNickname = true
    }

    func saveNickname() {
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

    func cancelNicknameEdit() {
        inputNickname = ""
        isEditingNickname = false
    }

    func startEditingBody() {
        inputWeight = weightKg > 0 ? WeightFormatter.format(weightKg) : ""
        inputHeight = heightCm > 0 ? String(format: "%.0f", heightCm) : ""
        inputAge = age > 0 ? "\(age)" : ""
        isEditingBody = true
    }

    func saveBodyData() {
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

    func cancelBodyEdit() {
        isEditingBody = false
    }

    func fetchBMI() {
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

    func loadInitialBMI() {
        if hasBodyData, bmiResult == nil {
            fetchBMI()
        }
    }
}
