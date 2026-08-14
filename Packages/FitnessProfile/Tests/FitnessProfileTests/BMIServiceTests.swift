import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("BMIService Tests", .tags(.fast))
struct BMIServiceTests {

    let service = BMIService()

    // MARK: - Local BMI Calculation

    @Test func calculateLocallyClassifiesAndRoundsValidInputs() throws {
        let cases: [(weight: Double, height: Double, value: Double, category: BMICategory)] = [
            (70, 1.75, 22.9, .normal),
            (50, 1.80, 15.4, .underweight),
            (90, 1.75, 29.4, .overweight),
            (120, 1.70, 41.5, .obese),
        ]

        for testCase in cases {
            let result = try #require(service.calculateBMILocally(
                weightKg: testCase.weight,
                heightM: testCase.height
            ))
            #expect(result.value == testCase.value)
            #expect(result.category == testCase.category)
        }
    }

    @Test func calculateLocallyRejectsNonPositiveInputs() {
        let cases: [(weight: Double, height: Double)] = [
            (0, 1.75),
            (70, 0),
            (-10, 1.75),
        ]

        for testCase in cases {
            #expect(service.calculateBMILocally(
                weightKg: testCase.weight,
                heightM: testCase.height
            ) == nil)
        }
    }

    // MARK: - BMICategory Parsing

    @Test func bmiCategoryParsesKnownVariantsAndUnknownValues() {
        let cases: [(input: String, category: BMICategory)] = [
            ("Underweight", .underweight),
            ("underweight", .underweight),
            ("Severely Underweight", .underweight),
            ("Normal weight", .normal),
            ("normal", .normal),
            ("Overweight", .overweight),
            ("overweight", .overweight),
            ("Obese", .obese),
            ("obese class I", .obese),
            ("Obesity", .obese),
            ("obesity", .obese),
            ("something else", .unknown),
            ("", .unknown),
        ]

        for testCase in cases {
            #expect(BMICategory(from: testCase.input) == testCase.category)
        }
    }

    // MARK: - Fetch BMI (input validation)

    @Test func fetchBMIRejectsInvalidInputs() async {
        for testCase in [(weight: 0.0, height: 1.75), (weight: 70.0, height: -1.0)] {
            do {
                _ = try await service.fetchBMI(
                    weightKg: testCase.weight,
                    heightM: testCase.height
                )
                Issue.record("Expected invalidInput error")
            } catch let error as BMIError {
                #expect(error == .invalidInput)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Stubbed API Tests (no network)

    @Test func fetchBMI_stubbedNormal_parsesCorrectly() async throws {
        let service = BMIService(session: StubURLProtocol.session(json: """
            {"bmi": 22.9, "Category": "Normal weight", "weight": 70.0, "height": 1.75}
            """))
        let result = try await service.fetchBMI(weightKg: 70, heightM: 1.75)
        #expect(result.category == .normal)
    }

    @Test func fetchBMIUnknownCategoriesFallBackToNumericBMI() async throws {
        let cases: [(json: String, weight: Double, category: BMICategory)] = [
            (#"{"bmi":37.0,"Category":"Morbid Obesity Class III","weight":113.0,"height":1.75}"#, 113, .obese),
            (#"{"bmi":22.0,"Category":"Gesund","weight":67.0,"height":1.75}"#, 67, .normal),
        ]

        for testCase in cases {
            let service = BMIService(session: StubURLProtocol.session(json: testCase.json))
            let result = try await service.fetchBMI(weightKg: testCase.weight, heightM: 1.75)
            #expect(result.category == testCase.category)
        }
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
