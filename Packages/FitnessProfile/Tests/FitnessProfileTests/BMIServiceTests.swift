import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("BMIService Tests", .tags(.fast))
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
        #expect(BMICategory(from: "Obesity") == .obese)
        #expect(BMICategory(from: "obesity") == .obese)
    }

    @Test func bmiCategory_unknownString_returnsUnknown() {
        #expect(BMICategory(from: "something else") == .unknown)
        #expect(BMICategory(from: "") == .unknown)
    }

    // MARK: - BMICategory DisplayName

    @Test func bmiCategory_displayNames() {
        #expect(BMICategory.underweight.displayName == "Underweight")
        #expect(BMICategory.normal.displayName == "Normal weight")
        #expect(BMICategory.overweight.displayName == "Overweight")
        #expect(BMICategory.obese.displayName == "Obese")
        #expect(BMICategory.unknown.displayName == "Unknown")
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

    // MARK: - Stubbed API Tests (no network)

    @Test func fetchBMI_stubbedObesity_parsesAsObese() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 35.3, "Category": "Obesity", "weight": 108.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 108, heightM: 1.75)
        #expect(result.category == .obese)
        #expect(result.value == 35.3)
    }

    @Test func fetchBMI_stubbedUnderweight_parsesCorrectly() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 16.3, "Category": "Underweight", "weight": 50.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 50, heightM: 1.75)
        #expect(result.category == .underweight)
    }

    @Test func fetchBMI_stubbedNormal_parsesCorrectly() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 22.9, "Category": "Normal weight", "weight": 70.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 70, heightM: 1.75)
        #expect(result.category == .normal)
    }

    @Test func fetchBMI_stubbedOverweight_parsesCorrectly() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 27.8, "Category": "Overweight", "weight": 85.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 85, heightM: 1.75)
        #expect(result.category == .overweight)
    }

    @Test func fetchBMI_stubbedUnknownCategory_fallsBackToBMIValue() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 37.0, "Category": "Morbid Obesity Class III", "weight": 113.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 113, heightM: 1.75)
        #expect(result.category == .obese, "Should fall back to BMI-value-based category, not .unknown")
    }

    @Test func fetchBMI_stubbedUnknownCategory_normalRange_fallsBack() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 22.0, "Category": "Gesund", "weight": 67.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 67, heightM: 1.75)
        #expect(result.category == .normal, "Should fall back to BMI-value-based category for unknown string")
    }

    @Test func fetchBMI_stubbed500_throwsServerError() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: "{}", statusCode: 500))
        do {
            _ = try await service.fetchBMI(weightKg: 70, heightM: 1.75)
            Issue.record("Expected serverError")
        } catch let error as BMIError {
            #expect(error == .serverError)
        }
    }
}

// MARK: - Stub URLProtocol

private final class StubURLProtocol: URLProtocol {
    private struct Stub {
        let data: Data
        let statusCode: Int
    }

    private static let lock = NSLock()
    private static var stubs: [String: Stub] = [:]

    static func session(json: String, statusCode: Int = 200) -> URLSession {
        let id = UUID().uuidString
        lock.lock()
        stubs[id] = Stub(data: Data(json.utf8), statusCode: statusCode)
        lock.unlock()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        config.httpAdditionalHeaders = ["X-Stub-ID": id]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "X-Stub-ID") != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-Stub-ID") ?? ""
        Self.lock.lock()
        let stub = Self.stubs.removeValue(forKey: id) ?? Stub(data: Data(), statusCode: 500)
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
