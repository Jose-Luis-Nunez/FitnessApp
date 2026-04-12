import Testing
import Foundation
@testable import FitnessApp

@Suite("BMIService Tests")
struct BMIServiceTests {

    let service = BMIService()

    // MARK: - Local BMI Calculation

    @Test func calculateLocally_normalWeight_returnsNormal() {
        let result = service.calculateBMILocally(weightKg: 70, heightM: 1.75)
        let unwrapped = try! #require(result)
        #expect(unwrapped.category == .normal)
        #expect(unwrapped.value >= 22.0 && unwrapped.value <= 23.0)
    }

    @Test func calculateLocally_underweight_returnsUnderweight() {
        let result = service.calculateBMILocally(weightKg: 50, heightM: 1.80)
        let unwrapped = try! #require(result)
        #expect(unwrapped.category == .underweight)
        #expect(unwrapped.value < 18.5)
    }

    @Test func calculateLocally_overweight_returnsOverweight() {
        let result = service.calculateBMILocally(weightKg: 90, heightM: 1.75)
        let unwrapped = try! #require(result)
        #expect(unwrapped.category == .overweight)
        #expect(unwrapped.value >= 25 && unwrapped.value < 30)
    }

    @Test func calculateLocally_obese_returnsObese() {
        let result = service.calculateBMILocally(weightKg: 120, heightM: 1.70)
        let unwrapped = try! #require(result)
        #expect(unwrapped.category == .obese)
        #expect(unwrapped.value >= 30)
    }

    @Test func calculateLocally_zeroWeight_returnsNil() {
        let result = service.calculateBMILocally(weightKg: 0, heightM: 1.75)
        #expect(result == nil)
    }

    @Test func calculateLocally_zeroHeight_returnsNil() {
        let result = service.calculateBMILocally(weightKg: 70, heightM: 0)
        #expect(result == nil)
    }

    @Test func calculateLocally_negativeWeight_returnsNil() {
        let result = service.calculateBMILocally(weightKg: -10, heightM: 1.75)
        #expect(result == nil)
    }

    @Test func calculateLocally_roundsToOneDecimal() {
        // 70 / (1.75^2) = 22.857... -> rounds to 22.9
        let result = service.calculateBMILocally(weightKg: 70, heightM: 1.75)
        let unwrapped = try! #require(result)
        let formatted = String(format: "%.1f", unwrapped.value)
        #expect(formatted == "22.9")
    }

    // MARK: - BMICategory Parsing

    @Test func bmiCategory_parsesUnderweight() {
        #expect(BMICategory(from: "Underweight") == .underweight)
        #expect(BMICategory(from: "underweight") == .underweight)
        #expect(BMICategory(from: "Severely Underweight") == .underweight)
    }

    @Test func bmiCategory_parsesNormal() {
        #expect(BMICategory(from: "Normal weight") == .normal)
        #expect(BMICategory(from: "normal") == .normal)
    }

    @Test func bmiCategory_parsesOverweight() {
        #expect(BMICategory(from: "Overweight") == .overweight)
        #expect(BMICategory(from: "overweight") == .overweight)
    }

    @Test func bmiCategory_parsesObese() {
        #expect(BMICategory(from: "Obese") == .obese)
        #expect(BMICategory(from: "obese class I") == .obese)
    }

    @Test func bmiCategory_unknownString_returnsUnknown() {
        #expect(BMICategory(from: "something else") == .unknown)
        #expect(BMICategory(from: "") == .unknown)
    }

    // MARK: - BMICategory DisplayName

    @Test func bmiCategory_displayNames() {
        #expect(BMICategory.underweight.displayName == "Untergewicht")
        #expect(BMICategory.normal.displayName == "Normalgewicht")
        #expect(BMICategory.overweight.displayName == "Übergewicht")
        #expect(BMICategory.obese.displayName == "Adipositas")
        #expect(BMICategory.unknown.displayName == "Unbekannt")
    }

    // MARK: - Fetch BMI (input validation)

    @Test func fetchBMI_invalidInput_throws() async {
        do {
            _ = try await service.fetchBMI(weightKg: 0, heightM: 1.75)
            Issue.record("Expected invalidInput error")
        } catch let error as BMIError {
            #expect(error == .invalidInput)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func fetchBMI_negativeHeight_throws() async {
        do {
            _ = try await service.fetchBMI(weightKg: 70, heightM: -1)
            Issue.record("Expected invalidInput error")
        } catch let error as BMIError {
            #expect(error == .invalidInput)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
