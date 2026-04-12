import Foundation

struct BMIResponse: Codable {
    let bmi: Double
    let Category: String
    let weight: Double
    let height: Double
}

enum BMICategory: String {
    case underweight = "Underweight"
    case normal = "Normal weight"
    case overweight = "Overweight"
    case obese = "Obese"
    case unknown = "Unknown"

    var displayName: String {
        switch self {
        case .underweight: return "Untergewicht"
        case .normal: return "Normalgewicht"
        case .overweight: return "Übergewicht"
        case .obese: return "Adipositas"
        case .unknown: return "Unbekannt"
        }
    }

    init(from apiCategory: String) {
        switch apiCategory.lowercased() {
        case let s where s.contains("underweight"):
            self = .underweight
        case let s where s.contains("normal"):
            self = .normal
        case let s where s.contains("overweight"):
            self = .overweight
        case let s where s.contains("obese"):
            self = .obese
        default:
            self = .unknown
        }
    }
}

struct BMIResult {
    let value: Double
    let category: BMICategory
}

final class BMIService {
    private let baseURL = "https://bmicalculatorapi.vercel.app/api/bmi"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches BMI from the API. Weight in kg, height in meters.
    func fetchBMI(weightKg: Double, heightM: Double) async throws -> BMIResult {
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
        return BMIResult(
            value: decoded.bmi,
            category: BMICategory(from: decoded.Category)
        )
    }

    /// Local fallback: BMI = weight / height^2
    func calculateBMILocally(weightKg: Double, heightM: Double) -> BMIResult? {
        guard weightKg > 0, heightM > 0 else { return nil }

        let bmi = weightKg / (heightM * heightM)
        let category: BMICategory
        switch bmi {
        case ..<18.5: category = .underweight
        case 18.5..<25: category = .normal
        case 25..<30: category = .overweight
        default: category = .obese
        }
        return BMIResult(value: (bmi * 10).rounded() / 10, category: category)
    }
}

enum BMIError: LocalizedError {
    case invalidInput
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Ungültige Eingabe für Gewicht oder Größe."
        case .invalidURL: return "Ungültige URL."
        case .serverError: return "Server nicht erreichbar."
        }
    }
}
