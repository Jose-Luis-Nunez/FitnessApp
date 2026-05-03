import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("TramDeparturesCache Tests", .tags(.fast))
struct TramDeparturesCacheTests {

    // MARK: - Helpers

    private static func makeDeparture(id: String, delaySeconds: TimeInterval = 0) -> TramDeparture {
        let planned = Date(timeIntervalSince1970: 1_714_000_000)
        return TramDeparture(
            id: id,
            line: "21",
            direction: "Marktstr.",
            plannedWhen: planned,
            when: planned.addingTimeInterval(delaySeconds)
        )
    }

    private static func freshDefaults(suite: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: - Roundtrip

    @Test func saveAndLoad_roundtrips() {
        let defaults = Self.freshDefaults()
        let cache = TramDeparturesCache(defaults: defaults)
        let payload = [
            Self.makeDeparture(id: "a", delaySeconds: 60),
            Self.makeDeparture(id: "b", delaySeconds: 0)
        ]
        cache.save(fromStopId: "100", toStopId: "200", line: "21", departures: payload)
        let loaded = cache.load(fromStopId: "100", toStopId: "200", line: "21")
        #expect(loaded != nil)
        #expect(loaded?.departures.count == 2)
        #expect(loaded?.departures.first?.id == "a")
        #expect(loaded?.departures.first?.delayMinutes == 1)
    }

    @Test func load_missingKey_returnsNil() {
        let defaults = Self.freshDefaults()
        let cache = TramDeparturesCache(defaults: defaults)
        #expect(cache.load(fromStopId: "x", toStopId: "y", line: "21") == nil)
    }

    // MARK: - Direction Independence

    @Test func differentDirections_useIndependentKeys() {
        let defaults = Self.freshDefaults()
        let cache = TramDeparturesCache(defaults: defaults)
        cache.save(
            fromStopId: "A", toStopId: "B", line: "21",
            departures: [Self.makeDeparture(id: "ab")]
        )
        cache.save(
            fromStopId: "B", toStopId: "A", line: "21",
            departures: [Self.makeDeparture(id: "ba")]
        )
        let forward = cache.load(fromStopId: "A", toStopId: "B", line: "21")
        let reverse = cache.load(fromStopId: "B", toStopId: "A", line: "21")
        #expect(forward?.departures.first?.id == "ab")
        #expect(reverse?.departures.first?.id == "ba")
    }

    @Test func differentLines_useIndependentKeys() {
        let defaults = Self.freshDefaults()
        let cache = TramDeparturesCache(defaults: defaults)
        cache.save(
            fromStopId: "A", toStopId: "B", line: "21",
            departures: [Self.makeDeparture(id: "tram-21")]
        )
        cache.save(
            fromStopId: "A", toStopId: "B", line: "27",
            departures: [Self.makeDeparture(id: "tram-27")]
        )
        #expect(cache.load(fromStopId: "A", toStopId: "B", line: "21")?.departures.first?.id == "tram-21")
        #expect(cache.load(fromStopId: "A", toStopId: "B", line: "27")?.departures.first?.id == "tram-27")
    }

    // MARK: - Resilience

    @Test func corruptedJSON_loadReturnsNil() {
        let suite = UUID().uuidString
        let defaults = Self.freshDefaults(suite: suite)
        let cache = TramDeparturesCache(defaults: defaults)
        let key = TramDeparturesCache.key(line: "21", from: "A", to: "B")
        defaults.set(Data([0x00, 0x01, 0xFF]), forKey: key)
        #expect(cache.load(fromStopId: "A", toStopId: "B", line: "21") == nil)
    }

    @Test func savePersistsTimestampCloseToNow() {
        let defaults = Self.freshDefaults()
        let cache = TramDeparturesCache(defaults: defaults)
        let before = Date()
        cache.save(fromStopId: "A", toStopId: "B", line: "21", departures: [Self.makeDeparture(id: "x")])
        let loaded = cache.load(fromStopId: "A", toStopId: "B", line: "21")
        let after = Date()
        #expect(loaded != nil)
        let saved = loaded!.savedAt
        #expect(saved >= before.addingTimeInterval(-1))
        #expect(saved <= after.addingTimeInterval(1))
    }
}
