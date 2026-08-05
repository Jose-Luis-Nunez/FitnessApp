import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

/// Integration tests for the slim `BVGSBahnService` orchestrator. The
/// classifier and bridge resolver have their own focused suites — these
/// tests only verify the wiring: client called for origin, transfer-pool
/// fetches happen iff needsBridge, results sorted + clipped, bridge-less
/// short-turns dropped.
@Suite("BVGSBahnService Integration Tests", .tags(.fast))
struct BVGSBahnServiceTests {

    // MARK: - Helpers

    private final class MockClient: BVGTransitClienting, @unchecked Sendable {
        var pools: [String: [TransitDeparture]] = [:]
        var stopovers: [String: [TransitStopover]] = [:]
        var error: BVGSBahnError?
        var failingStopoverTripIds: Set<String> = []
        var stopoverRequestGate: StopoverRequestGate?
        private let lock = NSLock()
        private var storedFetchedStopIds: [String] = []
        private var storedFetchedDirections: [String?] = []
        private var storedFetchedTripIds: [String] = []
        private var activeStopoverRequests = 0
        private var storedMaxConcurrentStopoverRequests = 0

        var fetchedStopIds: [String] { withLock { storedFetchedStopIds } }
        var fetchedDirections: [String?] { withLock { storedFetchedDirections } }
        var fetchedTripIds: [String] { withLock { storedFetchedTripIds } }
        var maxConcurrentStopoverRequests: Int { withLock { storedMaxConcurrentStopoverRequests } }

        func fetchSuburbanDepartures(
            stopId: String,
            directionStopId: String?
        ) async throws -> [TransitDeparture] {
            withLock {
                storedFetchedStopIds.append(stopId)
                storedFetchedDirections.append(directionStopId)
            }
            if let error { throw error }
            return pools[stopId] ?? []
        }

        func fetchTripStopovers(tripId: String) async throws -> [TransitStopover] {
            beginStopoverRequest(tripId: tripId)
            defer { endStopoverRequest() }
            if let stopoverRequestGate {
                await stopoverRequestGate.wait()
            }
            if failingStopoverTripIds.contains(tripId) {
                throw BVGSBahnError.network
            }
            return stopovers[tripId] ?? []
        }

        private func beginStopoverRequest(tripId: String) {
            withLock {
                storedFetchedTripIds.append(tripId)
                activeStopoverRequests += 1
                storedMaxConcurrentStopoverRequests = max(
                    storedMaxConcurrentStopoverRequests,
                    activeStopoverRequests
                )
            }
        }

        private func endStopoverRequest() {
            withLock { activeStopoverRequests -= 1 }
        }

        @discardableResult
        private func withLock<T>(_ operation: () -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return operation()
        }
    }

    private actor StopoverRequestGate {
        private var blocked: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            await withCheckedContinuation { continuation in
                blocked.append(continuation)
            }
        }

        func releaseAll() {
            let continuations = blocked
            blocked.removeAll()
            continuations.forEach { $0.resume() }
        }
    }

    private static func dep(
        _ hhmm: String,
        line: String,
        direction: String,
        tripId: String?
    ) -> TransitDeparture {
        let comps = hhmm.split(separator: ":")
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 8
        c.hour = Int(comps[0])!; c.minute = Int(comps[1])!
        let when = Calendar(identifier: .gregorian).date(from: c)!
        return TransitDeparture(tripId: tripId, line: line, direction: direction, plannedWhen: when, when: when)
    }

    private static let config = SBahnRouteConfiguration.standardBerlin

    // MARK: - Happy path: only east-direct, no transfer-pool calls

    @Test func onlyEastDirect_doesNotFetchTransferPools() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S3", direction: "S Erkner Bhf", tripId: "alex-S3"),
            Self.dep("06:46", line: "S7", direction: "S Ahrensfelde Bhf (Berlin)", tripId: "alex-S7"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 10
        )

        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.bridge == nil })
        // Only the origin call happened, no transfer-pool fetches.
        #expect(client.fetchedStopIds == [Self.config.originStopId])
    }

    // MARK: - east-bypass S9 with standalone bridge → shown with hint

    @Test func s9Bypass_withEigenständigBridge_isShownWithHint() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("23:02", line: "S9", direction: "S Schöneweide Bhf", tripId: "alex-S9"),
        ]
        client.pools[Self.config.transferStopIds[.ostbahnhof]!] = [
            Self.dep("23:08", line: "S3", direction: "S Friedrichshagen", tripId: "ostbf-S3-eigenständig"),
        ]
        client.pools[Self.config.transferStopIds[.warschauer]!] = []

        let service = BVGSBahnService(client: client, configuration: Self.config)
        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 10
        )

        let s9 = try #require(result.first { $0.id == "alex-S9" })
        #expect(s9.bridge?.bridgeLine == "S3")
        #expect(s9.bridge?.transferStation == "S Ostbahnhof")
    }

    // MARK: - east-short@Ostbahnhof with no bridge → filtered

    @Test func eastShortOstbahnhof_withoutBridge_isFiltered() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("23:15", line: "S7", direction: "S Ostbahnhof (Berlin)", tripId: "alex-S7-shortturn"),
        ]
        // Empty pool = no bridge available.
        client.pools[Self.config.transferStopIds[.ostbahnhof]!] = []
        client.pools[Self.config.transferStopIds[.warschauer]!] = []

        let service = BVGSBahnService(client: client, configuration: Self.config)
        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 10
        )

        #expect(result.contains { $0.id == "alex-S7-shortturn" } == false)
    }

    // MARK: - Pass-Through bridge tripId is rejected

    @Test func passThrough_bridgeTrip_isRejected() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("23:00", line: "S3", direction: "S Erkner Bhf", tripId: "alex-S3-passer"),
            Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9"),
        ]
        // Same tripId as the Alex S3 → Pass-Through, must not count as bridge.
        client.pools[Self.config.transferStopIds[.ostbahnhof]!] = [
            Self.dep("23:08", line: "S3", direction: "S Erkner Bhf", tripId: "alex-S3-passer"),
        ]
        client.pools[Self.config.transferStopIds[.warschauer]!] = []

        let service = BVGSBahnService(client: client, configuration: Self.config)
        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 10
        )

        // S9 must be filtered (only Pass-Through bridge available).
        #expect(result.contains { $0.id == "alex-S9" } == false)
    }

    // MARK: - Westbound trip is filtered

    @Test func westbound_isFiltered() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S5", direction: "S Westkreuz (Berlin)", tripId: "alex-S5-west"),
            Self.dep("06:45", line: "S7", direction: "S Ahrensfelde Bhf (Berlin)", tripId: "alex-S7"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 10
        )

        #expect(result.count == 1)
        #expect(result[0].id == "alex-S7")
    }

    // MARK: - Sorting + maxResults clipping

    @Test func sortsByPlannedTimeAndClipsToMaxResults() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("07:00", line: "S3", direction: "S Erkner Bhf", tripId: "third"),
            Self.dep("06:45", line: "S7", direction: "S Ahrensfelde Bhf (Berlin)", tripId: "first"),
            Self.dep("06:48", line: "S5", direction: "S Strausberg Nord", tripId: "second"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 2
        )

        #expect(result.map(\.id) == ["first", "second"])
    }

    @Test func sixtyDepartures_fetchOnlyFourDetailsWithAtMostFourConcurrentRequests() async throws {
        let client = MockClient()
        let requestGate = StopoverRequestGate()
        client.stopoverRequestGate = requestGate
        let start = Self.dep("06:00", line: "S3", direction: "S Erkner Bhf", tripId: "trip-0").plannedWhen
        client.pools[Self.config.originStopId] = (0..<60).map { index in
            let when = start.addingTimeInterval(TimeInterval(index * 60))
            return TransitDeparture(
                tripId: "trip-\(index)",
                line: "S3",
                direction: "S Erkner Bhf",
                plannedWhen: when,
                when: when
            )
        }
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let request = Task {
            try await service.fetchSBahnRoute(
                fromStopId: Self.config.originStopId,
                toStopId: Self.config.destinationStopId,
                maxResults: 4
            )
        }
        do {
            try await waitUntil { client.fetchedTripIds.count == 4 }
        } catch {
            await requestGate.releaseAll()
            request.cancel()
            _ = try? await request.value
            throw error
        }

        #expect(Set(client.fetchedTripIds) == Set(["trip-0", "trip-1", "trip-2", "trip-3"]))
        #expect(client.fetchedTripIds.count == 4)
        #expect(client.maxConcurrentStopoverRequests == 4)
        await requestGate.releaseAll()
        let result = try await request.value
        #expect(result.map(\.id) == ["trip-0", "trip-1", "trip-2", "trip-3"])
    }

    @Test func duplicateTripIds_areFetchedOnlyOnce() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S3", direction: "S Erkner Bhf", tripId: "same-trip"),
            Self.dep("06:44", line: "S3", direction: "S Erkner Bhf", tripId: "same-trip"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 4
        )

        #expect(client.fetchedTripIds == ["same-trip"])
        #expect(result.map(\.id) == ["same-trip"])
    }

    @Test func departuresWithoutTripIdsUseTheirFullFallbackIdentity() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S3", direction: "S Erkner Bhf", tripId: nil),
            Self.dep("06:42", line: "S3", direction: "S Ahrensfelde Bhf (Berlin)", tripId: nil),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 4
        )

        #expect(result.count == 2)
        #expect(Set(result.map(\.id)).count == 2)
        #expect(client.fetchedTripIds.isEmpty)
    }

    @Test func fallbackIdentityRemainsStableWhenLiveTimeChanges() async throws {
        let client = MockClient()
        let scheduled = Self.dep(
            "06:42",
            line: "S3",
            direction: "S Erkner Bhf",
            tripId: nil
        )
        client.pools[Self.config.originStopId] = [scheduled]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let first = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )
        client.pools[Self.config.originStopId] = [
            TransitDeparture(
                tripId: nil,
                line: scheduled.line,
                direction: scheduled.direction,
                plannedWhen: scheduled.plannedWhen,
                when: scheduled.when.addingTimeInterval(120)
            )
        ]
        let second = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )

        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func zeroResults_doesNotFetchStopovers() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S3", direction: "S Erkner Bhf", tripId: "unused"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 0
        )

        #expect(result.isEmpty)
        #expect(client.fetchedStopIds.isEmpty)
        #expect(client.fetchedTripIds.isEmpty)
    }

    @Test func negativeMaxResultsDoesNotFetchAnything() async throws {
        let client = MockClient()
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let result = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: -1
        )

        #expect(result.isEmpty)
        #expect(client.fetchedStopIds.isEmpty)
        #expect(client.fetchedTripIds.isEmpty)
    }

    @Test func failedStopoverFallsBackAndRemainsRetryable() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:42", line: "S3", direction: "S Erkner Bhf", tripId: "retry-trip")
        ]
        client.failingStopoverTripIds = ["retry-trip"]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        let first = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )
        #expect(first.count == 1)

        client.failingStopoverTripIds = []
        let second = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )

        #expect(second.count == 1)
        #expect(client.fetchedTripIds == ["retry-trip", "retry-trip"])
    }

    @Test func repeatedRefreshFetchesStopoversAgain() async throws {
        let client = MockClient()
        client.pools[Self.config.originStopId] = [
            Self.dep("06:00", line: "S3", direction: "S Erkner Bhf", tripId: "fresh-trip"),
        ]
        let service = BVGSBahnService(client: client, configuration: Self.config)

        _ = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )
        _ = try await service.fetchSBahnRoute(
            fromStopId: Self.config.originStopId,
            toStopId: Self.config.destinationStopId,
            maxResults: 1
        )

        #expect(client.fetchedTripIds == ["fresh-trip", "fresh-trip"])
    }

    // MARK: - Reverse direction (Ostkreuz → Alex) with bridge logic

    @Test func reverseDirection_shortTurnAtOstbahnhof_withEigenständigBridge_isShown() async throws {
        let reverseConfig = SBahnRouteConfiguration.standardBerlinReverse
        let client = MockClient()
        // Origin = Ostkreuz (reverse). Two trips: one short-turn at Ostbf,
        // one direct to Spandau.
        client.pools[reverseConfig.originStopId] = [
            Self.dep("23:02", line: "S5", direction: "S Ostbahnhof (Berlin)", tripId: "ostkz-S5-shortturn"),
            Self.dep("23:05", line: "S3", direction: "S Spandau Bhf (Berlin)", tripId: "ostkz-S3-direct"),
        ]
        // Standalone bridge at Ostbahnhof going further west.
        client.pools[reverseConfig.transferStopIds[.ostbahnhof]!] = [
            Self.dep("23:08", line: "S7", direction: "S Charlottenburg Bhf (Berlin)", tripId: "ostbf-S7-eigenständig"),
        ]
        client.pools[reverseConfig.transferStopIds[.warschauer]!] = []

        let service = BVGSBahnService(client: client, configuration: reverseConfig)
        let result = try await service.fetchSBahnRoute(
            fromStopId: reverseConfig.originStopId,
            toStopId: reverseConfig.destinationStopId,
            maxResults: 10
        )

        // Direct trip shown without bridge.
        let direct = try #require(result.first { $0.id == "ostkz-S3-direct" })
        #expect(direct.bridge == nil)

        // Short-turn shown with bridge hint.
        let shortTurn = try #require(result.first { $0.id == "ostkz-S5-shortturn" })
        #expect(shortTurn.bridge?.bridgeLine == "S7")
        #expect(shortTurn.bridge?.transferStation == "S Ostbahnhof")
    }

    @Test func reverseDirection_eastboundTrip_isFilteredAsWrongDirection() async throws {
        let reverseConfig = SBahnRouteConfiguration.standardBerlinReverse
        let client = MockClient()
        // From Ostkreuz, an eastbound S3 → Erkner is going AWAY from Alex.
        client.pools[reverseConfig.originStopId] = [
            Self.dep("23:02", line: "S3", direction: "S Erkner Bhf", tripId: "ostkz-S3-east-wrong"),
            Self.dep("23:05", line: "S5", direction: "S Westkreuz (Berlin)", tripId: "ostkz-S5-west"),
        ]
        let service = BVGSBahnService(client: client, configuration: reverseConfig)
        let result = try await service.fetchSBahnRoute(
            fromStopId: reverseConfig.originStopId,
            toStopId: reverseConfig.destinationStopId,
            maxResults: 10
        )

        #expect(result.contains { $0.id == "ostkz-S3-east-wrong" } == false)
        #expect(result.contains { $0.id == "ostkz-S5-west" })
    }

    // MARK: - HTTP error propagates

    @Test func httpError_propagates() async throws {
        let client = MockClient()
        client.error = .rateLimited
        let service = BVGSBahnService(client: client, configuration: Self.config)
        do {
            _ = try await service.fetchSBahnRoute(
                fromStopId: Self.config.originStopId,
                toStopId: Self.config.destinationStopId,
                maxResults: 6
            )
            Issue.record("Expected rateLimited")
        } catch let error as BVGSBahnError {
            #expect(error == .rateLimited)
        }
    }
}
