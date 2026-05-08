import Testing
import Foundation
@testable import FitnessProfile

@Suite("SBahnBridgeResolver Tests", .tags(.fast))
struct SBahnBridgeResolverTests {

    private let config = SBahnRouteConfiguration.standardBerlin

    // MARK: - Test fixture builders

    /// Builds a `TransitDeparture` at a given Friday wall-clock time.
    private static func dep(
        _ hhmm: String,
        line: String = "S3",
        direction: String = "S Erkner Bhf",
        tripId: String = "trip-\(UUID().uuidString.prefix(6))"
    ) -> TransitDeparture {
        let comps = hhmm.split(separator: ":")
        let hour = Int(comps[0])!
        let min = Int(comps[1])!
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 8
        c.hour = hour; c.minute = min
        let cal = Calendar(identifier: .gregorian)
        let when = cal.date(from: c)!
        return TransitDeparture(tripId: tripId, line: line, direction: direction, plannedWhen: when, when: when)
    }

    // MARK: - eigenständig found at Ostbahnhof

    @Test("Eigenständig bridge at Ostbahnhof is returned")
    func eigenständigBridge_atOstbahnhof_isReturned() {
        // S9 leaves Alex 23:02; user arrives Ostbahnhof 23:06.
        // Bridge window: [23:06, 23:11].
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        let bridge = Self.dep("23:08", line: "S3", direction: "S Erkner Bhf", tripId: "ostbf-S3-eigenständig")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof, .warschauer],
            pools: [.ostbahnhof: [bridge], .warschauer: []],
            alexTripIds: ["alex-S9"],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result?.bridgeLine == "S3")
        #expect(result?.transferStation == "S Ostbahnhof")
    }

    // MARK: - Pass-Through trip is rejected (eigenständig violation)

    @Test("Pass-Through bridge (tripId in alex pool) is rejected")
    func passThroughBridge_isRejected() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        // Bridge candidate has the SAME tripId as a trip from Alex —
        // i.e. it's a Pass-Through. Must not count.
        let passThrough = Self.dep("23:08", line: "S3", direction: "S Erkner Bhf", tripId: "alex-S3-passer")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof, .warschauer],
            pools: [.ostbahnhof: [passThrough], .warschauer: []],
            alexTripIds: ["alex-S9", "alex-S3-passer"],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }

    // MARK: - Out-of-window candidates are rejected

    @Test("Bridge before user arrival is rejected")
    func bridgeBeforeArrival_isRejected() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        // 23:05 is before user's 23:06 arrival at Ostbahnhof.
        let tooEarly = Self.dep("23:05", line: "S3", direction: "S Erkner Bhf", tripId: "too-early")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof],
            pools: [.ostbahnhof: [tooEarly]],
            alexTripIds: ["alex-S9"],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }

    @Test("Bridge beyond 5-min window is rejected")
    func bridgeBeyondWindow_isRejected() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        // 23:12 = 6 min after arrival, 1 min beyond the window.
        let tooLate = Self.dep("23:12", line: "S3", direction: "S Erkner Bhf", tripId: "too-late")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof],
            pools: [.ostbahnhof: [tooLate]],
            alexTripIds: ["alex-S9"],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }

    // MARK: - Earliest bridge wins across transfer points

    @Test("Earliest bridge wins when both stops have candidates")
    func earliestBridge_winsAcrossStops() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        // Same trip seen at Ostbahnhof 23:08 and Warschauer 23:10 — pick
        // the earlier one (Ostbahnhof, 1 stop earlier in user's path).
        let ostbf = Self.dep("23:08", line: "S3", direction: "S Friedrichshagen", tripId: "shared-trip")
        let warsch = Self.dep("23:10", line: "S3", direction: "S Friedrichshagen", tripId: "shared-trip")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof, .warschauer],
            pools: [.ostbahnhof: [ostbf], .warschauer: [warsch]],
            alexTripIds: [],  // shared-trip is eigenständig — not from Alex
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result?.transferStation == "S Ostbahnhof")
    }

    // MARK: - Direction terminating at transfer stop is filtered

    @Test("Bridge candidate ending at Ostbahnhof is rejected")
    func candidate_endingAtOstbahnhof_isRejected() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        let endsAtOstbf = Self.dep("23:08", line: "S7", direction: "S Ostbahnhof (Berlin)", tripId: "ends-here")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof],
            pools: [.ostbahnhof: [endsAtOstbf]],
            alexTripIds: [],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }

    @Test("Westbound candidate is rejected")
    func westboundCandidate_isRejected() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        let westbound = Self.dep("23:08", line: "S3", direction: "S Spandau Bhf (Berlin)", tripId: "going-west")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof],
            pools: [.ostbahnhof: [westbound]],
            alexTripIds: [],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }

    // MARK: - Empty pool

    @Test("Empty pool returns nil")
    func emptyPool_returnsNil() {
        let s9 = Self.dep("23:02", line: "S9", direction: "Flughafen BER", tripId: "alex-S9")
        let inputs = SBahnBridgeResolver.Inputs(
            shortDeparture: s9,
            transferOptions: [.ostbahnhof, .warschauer],
            pools: [.ostbahnhof: [], .warschauer: []],
            alexTripIds: [],
            configuration: config
        )

        let result = SBahnBridgeResolver.resolve(inputs)

        #expect(result == nil)
    }
}
