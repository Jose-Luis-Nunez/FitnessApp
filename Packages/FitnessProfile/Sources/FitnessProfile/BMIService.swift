import Foundation

struct BMIResponse: Codable {
    let bmi: Double
    let Category: String
    let weight: Double
    let height: Double
}

public enum BMICategory: String {
    case underweight = "Underweight"
    case normal = "Normal weight"
    case overweight = "Overweight"
    case obese = "Obese"
    case unknown = "Unknown"

    public var displayName: String {
        switch self {
        case .underweight: return "Untergewicht"
        case .normal: return "Normalgewicht"
        case .overweight: return "Übergewicht"
        case .obese: return "Adipositas"
        case .unknown: return "Unbekannt"
        }
    }

    public init(from apiCategory: String) {
        switch apiCategory.lowercased() {
        case let s where s.contains("underweight"):
            self = .underweight
        case let s where s.contains("normal"):
            self = .normal
        case let s where s.contains("overweight"):
            self = .overweight
        case let s where s.contains("obese") || s.contains("obesity"):
            self = .obese
        default:
            self = .unknown
        }
    }

    /// Derives category from the numeric BMI value (WHO thresholds).
    public init(fromValue bmi: Double) {
        switch bmi {
        case ..<18.5: self = .underweight
        case 18.5..<25: self = .normal
        case 25..<30: self = .overweight
        default: self = .obese
        }
    }
}

public struct BMIResult {
    public let value: Double
    public let category: BMICategory

    public init(value: Double, category: BMICategory) {
        self.value = value
        self.category = category
    }
}

/// Protocol boundary for BMI resolution so `ProfileViewModel` can be unit-tested
/// without touching the network. `BMIService` is the production implementation;
/// tests inject a stub conforming to this protocol.
public protocol BMIServicing: Sendable {
    func fetchBMI(weightKg: Double, heightM: Double) async throws -> BMIResult
    func calculateBMILocally(weightKg: Double, heightM: Double) -> BMIResult?
}

public final class BMIService: BMIServicing, Sendable {
    private let baseURL = "https://bmicalculatorapi.vercel.app/api/bmi"
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches BMI from the API. Weight in kg, height in meters.
    public func fetchBMI(weightKg: Double, heightM: Double) async throws -> BMIResult {
        guard weightKg > 0, heightM > 0 else {
            throw BMIError.invalidInput
        }

        let urlString = "\(baseURL)/\(weightKg)/\(heightM)"
        guard let url = URL(string: urlString) else {
            throw BMIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BMIError.serverError
        }

        let decoded = try JSONDecoder().decode(BMIResponse.self, from: data)
        let parsed = BMICategory(from: decoded.Category)
        let category = (parsed == .unknown) ? BMICategory(fromValue: decoded.bmi) : parsed
        return BMIResult(value: decoded.bmi, category: category)
    }

    /// Local fallback: BMI = weight / height^2
    public func calculateBMILocally(weightKg: Double, heightM: Double) -> BMIResult? {
        guard weightKg > 0, heightM > 0 else { return nil }
        let bmi = weightKg / (heightM * heightM)
        return BMIResult(value: (bmi * 10).rounded() / 10, category: BMICategory(fromValue: bmi))
    }
}

public enum BMIError: LocalizedError, Equatable {
    case invalidInput
    case invalidURL
    case serverError

    public var errorDescription: String? {
        switch self {
        case .invalidInput: return "Ungültige Eingabe für Gewicht oder Größe."
        case .invalidURL: return "Ungültige URL."
        case .serverError: return "Server nicht erreichbar."
        }
    }
}
