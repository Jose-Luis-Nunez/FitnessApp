import Foundation
import SwiftUI
import FitnessUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @AppStorage("userNickname") var nickname: String = ""
    @AppStorage("userWeight") var weightKg: Double = 0
    @AppStorage("userHeight") var heightCm: Double = 0
    @AppStorage("userAge") var age: Int = 0

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
        }
        if let h = WeightFormatter.parse(inputHeight) {
            heightCm = h
        }
        if let a = Int(inputAge) {
            age = a
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
            } catch {
                if let local = bmiService.calculateBMILocally(weightKg: weightKg, heightM: heightM) {
                    bmiResult = local
                }
                bmiError = error.localizedDescription
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
