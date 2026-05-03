import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("BVGTramService Tests", .tags(.fast))
struct BVGTramServiceTests {

    private static let sampleJSON = """
    {
      "departures": [
        {
          "tripId": "trip-1",
          "direction": "Rummelsburg, Marktstraße",
          "when": "2026-04-21T19:21:00+02:00",
          "plannedWhen": "2026-04-21T19:21:00+02:00",
          "delay": 0,
          "line": { "name": "21", "product": "tram" }
        },
        {
          "tripId": "trip-2",
          "direction": "S Schöneweide",
          "when": "2026-04-21T19:33:00+02:00",
          "plannedWhen": "2026-04-21T19:30:00+02:00",
          "delay": 180,
          "line": { "name": "21", "product": "tram" }
        },
        {
          "tripId": "trip-3",
          "direction": "Rummelsburg, Marktstraße",
          "when": "2026-04-21T19:41:00+02:00",
          "plannedWhen": "2026-04-21T19:41:00+02:00",
          "delay": 0,
          "line": { "name": "21", "product": "tram" }
        },
        {
          "tripId": "trip-4",
          "direction": "Somewhere",
          "when": "2026-04-21T19:45:00+02:00",
          "plannedWhen": "2026-04-21T19:45:00+02:00",
          "delay": 0,
          "line": { "name": "M17", "product": "tram" }
        },
        {
          "tripId": "trip-5",
          "direction": "Rummelsburg, Marktstraße",
          "when": "2026-04-21T19:51:00+02:00",
          "plannedWhen": "2026-04-21T19:51:00+02:00",
          "delay": 0,
          "line": { "name": "21", "product": "tram" }
        }
      ]
    }
    """

    @Test func fetchDepartures_parsesAndFiltersLine() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: Self.sampleJSON))
        let result = try await service.fetchDepartures(
            fromStopId: "900162504",
            directionStopId: "900160535",
            line: "21",
            maxResults: 3
        )
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.line == "21" })
    }

    @Test func fetchDepartures_sortsByPlannedTime() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: Self.sampleJSON))
        let result = try await service.fetchDepartures(
            fromStopId: "900162504",
            directionStopId: "900160535",
            line: "21",
            maxResults: 10
        )
        let sorted = result.map(\.plannedWhen)
        #expect(sorted == sorted.sorted())
    }

    @Test func fetchDepartures_computesDelayMinutes() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: Self.sampleJSON))
        let result = try await service.fetchDepartures(
            fromStopId: "900162504",
            directionStopId: "900160535",
            line: "21",
            maxResults: 10
        )
        let delayed = try #require(result.first { $0.id == "trip-2" })
        #expect(delayed.delayMinutes == 3)
    }

    @Test func fetchDepartures_filtersOtherLines() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: Self.sampleJSON))
        let result = try await service.fetchDepartures(
            fromStopId: "900162504",
            directionStopId: "900160535",
            line: "21",
            maxResults: 10
        )
        #expect(result.allSatisfy { $0.line == "21" })
        #expect(result.contains { $0.id == "trip-4" } == false)
    }

    @Test func fetchDepartures_429_throwsRateLimited() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: "{}", statusCode: 429))
        do {
            _ = try await service.fetchDepartures(
                fromStopId: "900162504",
                directionStopId: "900160535",
                line: "21",
                maxResults: 3
            )
            Issue.record("Expected rateLimited error")
        } catch let error as BVGTramError {
            #expect(error == .rateLimited)
        }
    }

    @Test func fetchDepartures_500_throwsServerError() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: "{}", statusCode: 500))
        do {
            _ = try await service.fetchDepartures(
                fromStopId: "900162504",
                directionStopId: "900160535",
                line: "21",
                maxResults: 3
            )
            Issue.record("Expected serverError")
        } catch let error as BVGTramError {
            #expect(error == .serverError)
        }
    }

    @Test func fetchDepartures_malformedJSON_throwsDecoding() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: "not json"))
        do {
            _ = try await service.fetchDepartures(
                fromStopId: "900162504",
                directionStopId: "900160535",
                line: "21",
                maxResults: 3
            )
            Issue.record("Expected decoding error")
        } catch let error as BVGTramError {
            #expect(error == .decoding)
        }
    }

    @Test func fetchDepartures_emptyDepartures_returnsEmpty() async throws {
        let service = BVGTramService(session: StubURLProtocol.session(json: """
            {"departures": []}
            """))
        let result = try await service.fetchDepartures(
            fromStopId: "900162504",
            directionStopId: "900160535",
            line: "21",
            maxResults: 3
        )
        #expect(result.isEmpty)
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
