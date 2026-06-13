import Foundation

// MARK: - Protocol

public protocol BVGSBahnServicing: Sendable {
    /// Fetches the next S-Bahn departures from `fromStopId` heading toward
    /// `toStopId` (Ostkreuz). Each departure is either `east-direct`
    /// (passes through Ostkreuz on its own) or carries a `BridgeHint`
    /// pointing at a standalone connecting train at Ostbahnhof or
    /// Warschauer. Trips with no useful bridge are filtered out so the
    /// user never sees a "useless" short-turn.
    func fetchSBahnRoute(
        fromStopId: String,
        toStopId: String,
        maxResults: Int
    ) async throws -> [SBahnDeparture]
}

// MARK: - Service (slim orchestrator)

/// Composes `BVGTransitClient`, `SBahnClassifier`, and `SBahnBridgeResolver`
/// into the user-visible Alex → Ostkreuz routing. The class itself is
/// almost stateless: it holds the injected dependencies and runs the
/// 4-step orchestration on each `fetchSBahnRoute` call.
public final class BVGSBahnService: BVGSBahnServicing, @unchecked Sendable {
    private let client: BVGTransitClienting
    private let routeConfigurations: [SBahnRouteConfiguration]

    /// In-memory cache of stopover-list-per-tripId, populated lazily as
    /// trips show up in refresh results. Within a session a tripId's
    /// stopover list is stable, so caching avoids re-fetching on every
    /// 60s auto-refresh. Cleared on service deallocation (i.e. typically
    /// only on app cold start).
    private let stopoversCacheLock = NSLock()
    private var stopoversCache: [String: [TransitStopover]] = [:]

    public init(
        client: BVGTransitClienting = BVGTransitClient(),
        routeConfigurations: [SBahnRouteConfiguration] = [
            .standardBerlinForward,
            .standardBerlinReverse,
        ]
    ) {
        self.client = client
        self.routeConfigurations = routeConfigurations
    }

    /// Convenience init for callers that want a single-configuration setup
    /// (e.g. unit tests with a custom config). The supplied configuration
    /// is treated as the only matching route — calls with non-matching
    /// from/to fall through to the direction-filtered path.
    public convenience init(
        client: BVGTransitClienting,
        configuration: SBahnRouteConfiguration
    ) {
        self.init(client: client, routeConfigurations: [configuration])
    }

    /// Convenience init that mirrors the legacy signature (`baseURL` +
    /// `URLSession`). Kept for callers that wire this up directly without
    /// providing a custom client. Tests prefer the protocol-based init.
    public convenience init(baseURL: String, session: URLSession = .shared) {
        self.init(
            client: BVGTransitClient(baseURL: baseURL, session: session),
            routeConfigurations: [.standardBerlinForward, .standardBerlinReverse]
        )
    }

    public func fetchSBahnRoute(
        fromStopId: String,
        toStopId: String,
        maxResults: Int = 4
    ) async throws -> [SBahnDeparture] {
        // Match the requested (from, to) against all configured routes.
        // If a configuration matches, run the full classifier + bridge
        // pipeline against it — works symmetrically for forward and
        // reverse Stadtbahn directions.
        //
        // If no configuration matches (arbitrary routes), fall back to
        // the API's server-side `direction=` filter — correct but no
        // smart-bridge feature.
        if let config = routeConfigurations.first(where: {
            $0.originStopId == fromStopId && $0.destinationStopId == toStopId
        }) {
            return try await fetchWithBridges(
                fromStopId: fromStopId,
                configuration: config,
                maxResults: maxResults
            )
        } else {
            return try await fetchDirectionFiltered(
                fromStopId: fromStopId,
                toStopId: toStopId,
                maxResults: maxResults
            )
        }
    }

    // MARK: - Configured route (forward or reverse)

    private func fetchWithBridges(
        fromStopId: String,
        configuration config: SBahnRouteConfiguration,
        maxResults: Int
    ) async throws -> [SBahnDeparture] {
        let origin = try await client.fetchSuburbanDepartures(stopId: fromStopId)
        let originTripIds = Set(origin.compactMap(\.tripId))

        let classified: [(TransitDeparture, SBahnClassification)] = origin.compactMap { dep in
            let cls = SBahnClassifier.classify(
                line: dep.line,
                direction: dep.direction,
                configuration: config
            )
            guard cls != .west && cls != .unknown else { return nil }
            return (dep, cls)
        }

        let needsBridge = classified.contains { $0.1.needsBridge }
        let pools: [SBahnTransferStop: [TransitDeparture]] = needsBridge
            ? try await fetchTransferPools(configuration: config)
            : [:]

        // First-pass: build an intermediate list with bridge-resolved
        // trips and skip the rejects (east-short with no bridge).
        struct PreparedTrip {
            let dep: TransitDeparture
            let bridge: BridgeHint?
        }
        let prepared: [PreparedTrip] = classified.compactMap { dep, cls in
            if cls.needsBridge {
                let inputs = SBahnBridgeResolver.Inputs(
                    shortDeparture: dep,
                    transferOptions: cls.transferOptions,
                    pools: pools,
                    alexTripIds: originTripIds,
                    configuration: config
                )
                guard let bridge = SBahnBridgeResolver.resolve(inputs) else { return nil }
                return PreparedTrip(dep: dep, bridge: bridge)
            } else {
                return PreparedTrip(dep: dep, bridge: nil)
            }
        }

        // Second-pass: fetch stopovers in parallel for every trip whose
        // arrival we need. For non-bridge trips that's the original trip's
        // tripId; for bridge trips it's the BRIDGE train's tripId because
        // that's the train the user is on at the moment of arrival.
        let arrivalTripIds: [String] = prepared.compactMap { trip in
            if let bridge = trip.bridge { return bridge.bridgeTripId }
            return trip.dep.tripId
        }
        let stopoversByTripId = await fetchStopoversInParallel(tripIds: arrivalTripIds)

        // Third-pass: build SBahnDepartures with API-derived arrival when
        // available, falling back to the configuration's static estimate.
        let resolved: [SBahnDeparture] = prepared.map { trip in
            let arrival = arrivalAtDestination(
                dep: trip.dep,
                bridge: trip.bridge,
                stopoversByTripId: stopoversByTripId,
                configuration: config
            )
            return Self.makeDeparture(from: trip.dep, bridge: trip.bridge, arrival: arrival)
        }

        return Array(
            resolved
                .sorted { $0.plannedWhen < $1.plannedWhen }
                .prefix(max(maxResults, 0))
        )
    }

    // MARK: - Arrival lookup (API-truth via stopovers)

    private func fetchStopoversInParallel(
        tripIds: [String]
    ) async -> [String: [TransitStopover]] {
        // Hit the cache first so back-to-back refreshes don't re-fetch.
        var (hits, misses) = cachedStopoversAndMisses(for: tripIds)

        // Fetch the misses concurrently. A failed lookup just skips the
        // trip — the caller will fall back to the static estimate.
        let fetched: [String: [TransitStopover]] = await withTaskGroup(of: (String, [TransitStopover]?).self) { group in
            for tripId in misses {
                group.addTask { [client] in
                    let stopovers = try? await client.fetchTripStopovers(tripId: tripId)
                    return (tripId, stopovers)
                }
            }
            var result: [String: [TransitStopover]] = [:]
            for await (tripId, stopovers) in group {
                if let stopovers {
                    result[tripId] = stopovers
                }
            }
            return result
        }

        storeStopovers(fetched)
        for (tripId, stopovers) in fetched {
            hits[tripId] = stopovers
        }
        return hits
    }

    /// Synchronous helper around the cache lock — keeps the NSLock call
    /// out of the async context (Swift 6 compliance).
    private func cachedStopoversAndMisses(
        for tripIds: [String]
    ) -> (hits: [String: [TransitStopover]], misses: [String]) {
        stopoversCacheLock.lock()
        defer { stopoversCacheLock.unlock() }
        var hits: [String: [TransitStopover]] = [:]
        var misses: [String] = []
        for tripId in tripIds {
            if let cached = stopoversCache[tripId] {
                hits[tripId] = cached
            } else {
                misses.append(tripId)
            }
        }
        return (hits, misses)
    }

    /// Synchronous helper around the cache lock for inserts.
    private func storeStopovers(_ entries: [String: [TransitStopover]]) {
        stopoversCacheLock.lock()
        defer { stopoversCacheLock.unlock() }
        for (tripId, list) in entries {
            stopoversCache[tripId] = list
        }
    }

    private func arrivalAtDestination(
        dep: TransitDeparture,
        bridge: BridgeHint?,
        stopoversByTripId: [String: [TransitStopover]],
        configuration config: SBahnRouteConfiguration
    ) -> Date? {
        // Pick the trip whose stopovers contain the destination — bridge
        // train if there is one, original trip otherwise.
        let arrivalTripId = bridge?.bridgeTripId ?? dep.tripId

        if let tripId = arrivalTripId,
           let stopovers = stopoversByTripId[tripId],
           let destinationStop = stopovers.first(where: { $0.stopId == config.destinationStopId }),
           let arrival = destinationStop.arrival ?? destinationStop.plannedArrival {
            return arrival
        }

        // Fallback: static estimate derived from the configuration.
        if let bridge {
            return Self.arrivalForBridge(bridge: bridge, configuration: config)
        } else {
            return dep.plannedWhen.addingTimeInterval(config.travelToDestination)
        }
    }

    /// Static-estimate fallback used when the bridge-train stopover lookup
    /// fails. Same derivation as before: bridge departure + (origin →
    /// destination travel) − (origin → transfer-stop travel).
    private static func arrivalForBridge(
        bridge: BridgeHint,
        configuration config: SBahnRouteConfiguration
    ) -> Date? {
        let stop: SBahnTransferStop?
        switch bridge.transferStation {
        case SBahnTransferStop.ostbahnhof.displayName: stop = .ostbahnhof
        case SBahnTransferStop.warschauer.displayName: stop = .warschauer
        default: stop = nil
        }
        guard let stop, let originToStop = config.travelTimes[stop] else { return nil }
        let stopToDestination = config.travelToDestination - originToStop
        guard stopToDestination > 0 else { return nil }
        return bridge.bridgeDeparture.addingTimeInterval(stopToDestination)
    }

    // MARK: - Arbitrary route fallback (server-side direction filter)

    private func fetchDirectionFiltered(
        fromStopId: String,
        toStopId: String,
        maxResults: Int
    ) async throws -> [SBahnDeparture] {
        let trips = try await client.fetchSuburbanDepartures(
            stopId: fromStopId,
            directionStopId: toStopId
        )
        return Array(
            trips
                .map { Self.makeDeparture(from: $0, bridge: nil) }
                .sorted { $0.plannedWhen < $1.plannedWhen }
                .prefix(max(maxResults, 0))
        )
    }

    // MARK: - Internals

    private func fetchTransferPools(
        configuration config: SBahnRouteConfiguration
    ) async throws -> [SBahnTransferStop: [TransitDeparture]] {
        async let ostbf: [TransitDeparture] = {
            guard let id = config.transferStopIds[.ostbahnhof] else { return [] }
            return try await client.fetchSuburbanDepartures(stopId: id)
        }()
        async let warsch: [TransitDeparture] = {
            guard let id = config.transferStopIds[.warschauer] else { return [] }
            return try await client.fetchSuburbanDepartures(stopId: id)
        }()
        return try await [
            .ostbahnhof: ostbf,
            .warschauer: warsch,
        ]
    }

    private static func makeDeparture(
        from dep: TransitDeparture,
        bridge: BridgeHint?,
        arrival: Date? = nil
    ) -> SBahnDeparture {
        let id = dep.tripId ?? "\(dep.line)-\(dep.plannedWhen.timeIntervalSince1970)"
        return SBahnDeparture(
            id: id,
            line: dep.line,
            direction: dep.direction,
            plannedWhen: dep.plannedWhen,
            when: dep.when,
            bridge: bridge,
            arrivalAtDestination: arrival
        )
    }
}
