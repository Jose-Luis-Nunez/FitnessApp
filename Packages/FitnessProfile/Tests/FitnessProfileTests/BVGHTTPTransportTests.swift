import Foundation
import Testing
@testable import FitnessProfile

@Suite("BVG HTTP Transport Tests", .tags(.fast))
struct BVGHTTPTransportTests {
    @Test func retriesTemporaryServerFailureThenReturnsData() async throws {
        let harness = SequencedURLProtocol.makeSession(
            responses: [
                .init(statusCode: 503),
                .init(statusCode: 200, body: "ok"),
            ]
        )
        let delays = DelayRecorder()
        let transport = BVGHTTPTransport(
            session: harness.session,
            retryPolicy: .standard,
            sleep: { delay in await delays.record(delay) },
            randomUnit: { 0.5 }
        )

        let data = try await transport.data(from: Self.url)
        let recordedDelays = await delays.values

        #expect(String(decoding: data, as: UTF8.self) == "ok")
        #expect(SequencedURLProtocol.requestCount(for: harness.id) == 2)
        #expect(recordedDelays == [0.35])
    }

    @Test func stopsAfterBoundedRetryAndPreservesStatusCode() async throws {
        let harness = SequencedURLProtocol.makeSession(
            responses: [
                .init(statusCode: 503),
                .init(statusCode: 503),
            ]
        )
        let transport = BVGHTTPTransport(
            session: harness.session,
            retryPolicy: .standard,
            sleep: { _ in },
            randomUnit: { 0.5 }
        )

        do {
            _ = try await transport.data(from: Self.url)
            Issue.record("Expected the final HTTP status")
        } catch let error as BVGHTTPError {
            #expect(error == .httpStatus(503))
        }
        #expect(SequencedURLProtocol.requestCount(for: harness.id) == 2)
    }

    @Test func honorsBoundedRetryAfterHeader() async throws {
        let harness = SequencedURLProtocol.makeSession(
            responses: [
                .init(statusCode: 503, headers: ["Retry-After": "20"]),
                .init(statusCode: 200, body: "ok"),
            ]
        )
        let delays = DelayRecorder()
        let transport = BVGHTTPTransport(
            session: harness.session,
            retryPolicy: .standard,
            sleep: { delay in await delays.record(delay) },
            randomUnit: { 0.5 }
        )

        _ = try await transport.data(from: Self.url)
        let recordedDelays = await delays.values

        #expect(recordedDelays == [5])
    }

    @Test func cancellationDuringBackoffIsPropagatedWithoutAnotherRequest() async throws {
        let harness = SequencedURLProtocol.makeSession(
            responses: [.init(statusCode: 503)]
        )
        let transport = BVGHTTPTransport(
            session: harness.session,
            retryPolicy: .standard,
            sleep: { _ in throw CancellationError() },
            randomUnit: { 0.5 }
        )

        do {
            _ = try await transport.data(from: Self.url)
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation is part of task control flow, not a network failure.
        }
        #expect(SequencedURLProtocol.requestCount(for: harness.id) == 1)
    }

    private static let url = URL(string: "https://example.test/departures")!
}

private actor DelayRecorder {
    private var recordedValues: [TimeInterval] = []

    var values: [TimeInterval] { recordedValues }

    func record(_ value: TimeInterval) {
        recordedValues.append(value)
    }
}

private final class SequencedURLProtocol: URLProtocol {
    struct Response: Sendable {
        let statusCode: Int
        let body: String
        let headers: [String: String]

        init(
            statusCode: Int,
            body: String = "",
            headers: [String: String] = [:]
        ) {
            self.statusCode = statusCode
            self.body = body
            self.headers = headers
        }
    }

    struct Harness {
        let session: URLSession
        let id: String
    }

    private static let lock = NSLock()
    private static var responsesByID: [String: [Response]] = [:]
    private static var requestCountsByID: [String: Int] = [:]

    static func makeSession(responses: [Response]) -> Harness {
        let id = UUID().uuidString
        lock.lock()
        responsesByID[id] = responses
        requestCountsByID[id] = 0
        lock.unlock()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SequencedURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Stub-ID": id]
        return Harness(session: URLSession(configuration: configuration), id: id)
    }

    static func requestCount(for id: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCountsByID[id, default: 0]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "X-Stub-ID") != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-Stub-ID") ?? ""
        Self.lock.lock()
        Self.requestCountsByID[id, default: 0] += 1
        let response: Response
        if var remaining = Self.responsesByID[id], !remaining.isEmpty {
            response = remaining.removeFirst()
            Self.responsesByID[id] = remaining
        } else {
            response = Response(statusCode: 500)
        }
        Self.lock.unlock()

        var headers = response.headers
        headers["Content-Type"] = "application/json"
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
