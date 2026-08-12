import Foundation

/// Transport-level failures shared by the BVG departure clients.
/// Domain services map these into their feature-specific public error types.
enum BVGHTTPError: Error, Equatable {
    case network
    case rateLimited
    case httpStatus(Int)
}

/// Bounded retry configuration for transient transport.rest failures.
struct BVGRetryPolicy: Sendable, Equatable {
    let maximumRetryCount: Int
    let initialDelay: TimeInterval
    let maximumDelay: TimeInterval
    let maximumRetryAfterDelay: TimeInterval
    let jitterFraction: Double

    static let standard = BVGRetryPolicy(
        maximumRetryCount: 1,
        initialDelay: 0.35,
        maximumDelay: 2,
        maximumRetryAfterDelay: 5,
        jitterFraction: 0.2
    )

    static let disabled = BVGRetryPolicy(
        maximumRetryCount: 0,
        initialDelay: 0,
        maximumDelay: 0,
        maximumRetryAfterDelay: 0,
        jitterFraction: 0
    )
}

/// Small HTTP boundary that centralizes cancellation, transient retry, and
/// status-code handling for both Tram and S-Bahn clients.
final class BVGHTTPTransport: @unchecked Sendable {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    typealias RandomUnit = @Sendable () -> Double

    private static let retryableStatusCodes: Set<Int> = [502, 503, 504]
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .networkConnectionLost,
        .timedOut,
    ]

    private let session: URLSession
    private let retryPolicy: BVGRetryPolicy
    private let sleep: Sleep
    private let randomUnit: RandomUnit

    init(
        session: URLSession = .shared,
        retryPolicy: BVGRetryPolicy = .standard,
        sleep: @escaping Sleep = { seconds in
            let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
            try await Task<Never, Never>.sleep(nanoseconds: nanoseconds)
        },
        randomUnit: @escaping RandomUnit = { Double.random(in: 0...1) }
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
        self.sleep = sleep
        self.randomUnit = randomUnit
    }

    func data(from url: URL) async throws -> Data {
        var retryIndex = 0

        while true {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw BVGHTTPError.network
                }

                switch http.statusCode {
                case 200...299:
                    return data
                case 429:
                    throw BVGHTTPError.rateLimited
                case let statusCode where Self.retryableStatusCodes.contains(statusCode):
                    guard retryIndex < retryPolicy.maximumRetryCount else {
                        throw BVGHTTPError.httpStatus(statusCode)
                    }
                    let delay = retryDelay(for: http, retryIndex: retryIndex)
                    retryIndex += 1
                    try await sleep(delay)
                default:
                    throw BVGHTTPError.httpStatus(http.statusCode)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as URLError {
                guard Self.retryableURLErrorCodes.contains(error.code),
                      retryIndex < retryPolicy.maximumRetryCount else {
                    throw BVGHTTPError.network
                }
                let delay = retryDelay(response: nil, retryIndex: retryIndex)
                retryIndex += 1
                try await sleep(delay)
            } catch let error as BVGHTTPError {
                throw error
            } catch {
                throw BVGHTTPError.network
            }
        }
    }

    private func retryDelay(
        for response: HTTPURLResponse,
        retryIndex: Int
    ) -> TimeInterval {
        retryDelay(response: response, retryIndex: retryIndex)
    }

    private func retryDelay(
        response: HTTPURLResponse?,
        retryIndex: Int
    ) -> TimeInterval {
        if let retryAfter = response?.value(forHTTPHeaderField: "Retry-After"),
           let serverDelay = Self.retryAfterDelay(from: retryAfter) {
            return min(max(serverDelay, 0), retryPolicy.maximumRetryAfterDelay)
        }

        let exponential = min(
            retryPolicy.initialDelay * pow(2, Double(retryIndex)),
            retryPolicy.maximumDelay
        )
        let boundedRandom = min(max(randomUnit(), 0), 1)
        let jitter = 1 + ((boundedRandom * 2 - 1) * retryPolicy.jitterFraction)
        return max(0, exponential * jitter)
    }

    private static func retryAfterDelay(from value: String, now: Date = Date()) -> TimeInterval? {
        if let seconds = TimeInterval(value) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss z",
            "EEEE',' dd-MMM-yy HH':'mm':'ss z",
            "EEE MMM d HH':'mm':'ss yyyy",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date.timeIntervalSince(now)
            }
        }
        return nil
    }
}
