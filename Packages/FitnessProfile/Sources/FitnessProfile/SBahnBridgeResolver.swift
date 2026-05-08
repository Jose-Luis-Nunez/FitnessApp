import Foundation

// MARK: - Bridge Resolver

/// Pure logic that picks the best eigenständig bridge from a candidate pool.
/// Stateless, deterministic, no I/O — just iterates and applies the
/// configured filters.
public enum SBahnBridgeResolver {

    /// Inputs to a single resolution call. The pools are pre-fetched
    /// transit departures at the candidate transfer stops.
    public struct Inputs {
        public let shortDeparture: TransitDeparture
        public let transferOptions: [SBahnTransferStop]
        public let pools: [SBahnTransferStop: [TransitDeparture]]
        public let alexTripIds: Set<String>
        public let configuration: SBahnRouteConfiguration

        public init(
            shortDeparture: TransitDeparture,
            transferOptions: [SBahnTransferStop],
            pools: [SBahnTransferStop: [TransitDeparture]],
            alexTripIds: Set<String>,
            configuration: SBahnRouteConfiguration
        ) {
            self.shortDeparture = shortDeparture
            self.transferOptions = transferOptions
            self.pools = pools
            self.alexTripIds = alexTripIds
            self.configuration = configuration
        }
    }

    /// Returns the earliest eigenständig east-direct departure across all
    /// candidate transfer stops, or `nil` if none of the pools yields a
    /// useful bridge. Eigenständig means the trip's `tripId` is NOT present
    /// in the user's Alex-pool: i.e., it's an independent train the user
    /// could not catch by waiting at Alex.
    public static func resolve(_ inputs: Inputs) -> BridgeHint? {
        var best: (stop: SBahnTransferStop, candidate: TransitDeparture)?

        for stop in inputs.transferOptions {
            guard let pool = inputs.pools[stop],
                  let travel = inputs.configuration.travelTimes[stop] else { continue }

            let arrival = inputs.shortDeparture.when.addingTimeInterval(travel)
            let windowEnd = arrival.addingTimeInterval(inputs.configuration.bridgeWindow)

            let candidate = pool
                .filter { dep in
                    SBahnClassifier.isEastDirectAtTransfer(
                        line: dep.line,
                        direction: dep.direction,
                        configuration: inputs.configuration
                    )
                }
                .filter { $0.when >= arrival && $0.when <= windowEnd }
                .filter { dep in
                    // Strict eigenständig: trip must not be one the user
                    // could catch at Alex by waiting.
                    guard let tid = dep.tripId else { return true }
                    return !inputs.alexTripIds.contains(tid)
                }
                .sorted { $0.when < $1.when }
                .first

            guard let candidate else { continue }
            if let current = best {
                if candidate.when < current.candidate.when {
                    best = (stop, candidate)
                }
            } else {
                best = (stop, candidate)
            }
        }

        guard let best else { return nil }
        return BridgeHint(
            transferStation: best.stop.displayName,
            bridgeLine: best.candidate.line,
            bridgeDeparture: best.candidate.when,
            bridgeDirection: best.candidate.direction,
            bridgeOriginStation: nil,
            bridgeTripId: best.candidate.tripId
        )
    }
}
