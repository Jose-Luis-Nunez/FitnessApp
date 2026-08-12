import Testing
import Foundation
@testable import FitnessProfile

@Suite("BVGTransitClient Tests", .tags(.fast))
struct BVGTransitClientTests {

    private static let validJSON = """
    {
      "departures": [
        {
          "tripId": "trip-1",
          "direction": "S Erkner Bhf",
          "when": "2026-05-08T06:42:00+02:00",
          "plannedWhen": "2026-05-08T06:42:00+02:00",
          "line": { "name": "S3", "product": "suburban" }
        }
      ]
    }
    """

    @Test func fetchSuburbanDepartures_decodesAndMapsToDomain() async throws {
        let client = BVGTransitClient(session: StubURLProtocol.session(json: Self.validJSON))
        let result = try await client.fetchSuburbanDepartures(stopId: "900100003")
        #expect(result.count == 1)
        #expect(result[0].line == "S3")
        #expect(result[0].tripId == "trip-1")
        #expect(result[0].direction == "S Erkner Bhf")
    }

    @Test func fetchSuburbanDepartures_sendsRequiredRouteAndProductQuery() async throws {
        let session = StubURLProtocol.session(json: Self.validJSON)
        let client = BVGTransitClient(session: session)

        _ = try await client.fetchSuburbanDepartures(
            stopId: "900100003",
            directionStopId: "900120003"
        )

        let request = try #require(StubURLProtocol.recordedRequest(for: session))
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query: [String: String] = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )
        #expect(components.path == "/stops/900100003/departures")
        #expect(query["direction"] == "900120003")
        #expect(query["duration"] == "60")
        #expect(query["results"] == "60")
        #expect(query["suburban"] == "true")
        #expect(query["tram"] == "false")
        #expect(query["subway"] == "false")
        #expect(query["bus"] == "false")
        #expect(query["ferry"] == "false")
        #expect(query["express"] == "false")
        #expect(query["regional"] == "false")
        #expect(query["remarks"] == "false")
    }

    @Test func fetchSuburbanDepartures_dropsEntriesWithoutLineName() async throws {
        let json = """
        {
          "departures": [
            { "tripId": "no-line", "direction": "Anywhere", "when": "2026-05-08T06:42:00+02:00", "plannedWhen": "2026-05-08T06:42:00+02:00" },
            { "tripId": "ok", "direction": "S Erkner Bhf", "when": "2026-05-08T06:42:00+02:00", "plannedWhen": "2026-05-08T06:42:00+02:00", "line": { "name": "S3", "product": "suburban" } }
          ]
        }
        """
        let client = BVGTransitClient(session: StubURLProtocol.session(json: json))
        let result = try await client.fetchSuburbanDepartures(stopId: "900100003")
        #expect(result.count == 1)
        #expect(result[0].tripId == "ok")
    }

    @Test func fetchSuburbanDepartures_429_throwsRateLimited() async throws {
        let client = BVGTransitClient(session: StubURLProtocol.session(json: "{}", statusCode: 429))
        do {
            _ = try await client.fetchSuburbanDepartures(stopId: "900100003")
            Issue.record("Expected rateLimited")
        } catch let error as BVGSBahnError {
            #expect(error == .rateLimited)
        }
    }

    @Test func fetchSuburbanDepartures_500_throwsServerError() async throws {
        let client = BVGTransitClient(session: StubURLProtocol.session(json: "{}", statusCode: 500))
        do {
            _ = try await client.fetchSuburbanDepartures(stopId: "900100003")
            Issue.record("Expected serverError")
        } catch let error as BVGSBahnError {
            #expect(error == .serverError(statusCode: 500))
        }
    }

    @Test func fetchSuburbanDepartures_malformedJSON_throwsDecoding() async throws {
        let client = BVGTransitClient(session: StubURLProtocol.session(json: "not json"))
        do {
            _ = try await client.fetchSuburbanDepartures(stopId: "900100003")
            Issue.record("Expected decoding")
        } catch let error as BVGSBahnError {
            #expect(error == .decoding)
        }
    }

    @Test func fetchSuburbanDepartures_emptyArray_returnsEmpty() async throws {
        let client = BVGTransitClient(session: StubURLProtocol.session(json: "{\"departures\": []}"))
        let result = try await client.fetchSuburbanDepartures(stopId: "900100003")
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
    private static var requests: [String: URLRequest] = [:]

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

    static func recordedRequest(for session: URLSession) -> URLRequest? {
        guard let id = session.configuration.httpAdditionalHeaders?["X-Stub-ID"] as? String else {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return requests[id]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "X-Stub-ID") != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-Stub-ID") ?? ""
        Self.lock.lock()
        let stub = Self.stubs.removeValue(forKey: id) ?? Stub(data: Data(), statusCode: 500)
        Self.requests[id] = request
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
