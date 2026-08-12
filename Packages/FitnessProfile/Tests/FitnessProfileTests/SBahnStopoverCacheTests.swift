import Foundation
import Testing
@testable import FitnessProfile

@Suite("S-Bahn Stopover Cache Tests", .tags(.fast))
struct SBahnStopoverCacheTests {
    @Test func freshEntryIsReturnedUntilTTLExpires() async {
        let cache = SBahnStopoverCache(timeToLive: 60, capacity: 4)
        let storedAt = Date(timeIntervalSince1970: 1_000)
        await cache.store(
            stopoversByTripId: ["trip": [Self.stopover(id: "destination")]],
            now: storedAt
        )

        let fresh = await cache.lookup(
            tripIds: ["trip"],
            now: storedAt.addingTimeInterval(59)
        )
        let expired = await cache.lookup(
            tripIds: ["trip"],
            now: storedAt.addingTimeInterval(60)
        )

        #expect(fresh.stopoversByTripId["trip"]?.first?.stopId == "destination")
        #expect(fresh.missingTripIds.isEmpty)
        #expect(expired.stopoversByTripId.isEmpty)
        #expect(expired.missingTripIds == ["trip"])
    }

    @Test func capacityEvictsOldestEntry() async {
        let cache = SBahnStopoverCache(timeToLive: 60, capacity: 2)
        let storedAt = Date(timeIntervalSince1970: 1_000)
        await cache.store(
            stopoversByTripId: ["oldest": [Self.stopover(id: "one")]],
            now: storedAt
        )
        await cache.store(
            stopoversByTripId: ["middle": [Self.stopover(id: "two")]],
            now: storedAt.addingTimeInterval(1)
        )
        await cache.store(
            stopoversByTripId: ["newest": [Self.stopover(id: "three")]],
            now: storedAt.addingTimeInterval(2)
        )

        let lookup = await cache.lookup(
            tripIds: ["oldest", "middle", "newest"],
            now: storedAt.addingTimeInterval(3)
        )

        #expect(lookup.missingTripIds == ["oldest"])
        #expect(Set(lookup.stopoversByTripId.keys) == ["middle", "newest"])
    }

    private static func stopover(id: String) -> TransitStopover {
        TransitStopover(
            stopId: id,
            stopName: id,
            arrival: nil,
            departure: nil,
            plannedArrival: nil,
            plannedDeparture: nil
        )
    }
}
