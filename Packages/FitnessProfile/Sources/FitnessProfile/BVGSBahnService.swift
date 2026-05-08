import Foundation

// MARK: - Protocol

public protocol BVGSBahnServicing: Sendable {
    /// Fetches the next S-Bahn departures from `fromStopId` heading toward
    /// `toStopId` (Ostkreuz). Each departure is either `east-direct`
    /// (passes through Ostkreuz on its own) or carries a `BridgeHint`
    /// pointing at an eigenständig connecting train at Ostbahnhof or
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
    private let configuration: SBahnRouteConfiguration

    public init(
        client: BVGTransitClienting = BVGTransitClient(),
        configuration: SBahnRouteConfiguration = .standardBerlin
    ) {
        self.client = client
        self.configuration = configuration
    }

    /// Convenience init that mirrors the legacy signature (`baseURL` +
    /// `URLSession`). Kept for callers that wire this up directly without
    /// providing a custom client. Tests prefer the protocol-based init.
    public convenience init(baseURL: String, session: URLSession = .shared) {
        self.init(
            client: BVGTransitClient(baseURL: baseURL, session: session),
            configuration: .standardBerlin
        )
    }

    public func fetchSBahnRoute(
        fromStopId: String,
        toStopId: String,
        maxResults: Int = 4
    ) async throws -> [SBahnDeparture] {
        // Forward route (Alex → Ostkreuz, the configured direction): use
        // the full classifier + bridge-resolver pipeline so S9 bypass
        // trips get the smart-bridge hint.
        //
        // Any other route (e.g. swapped Ostkreuz → Alex, or arbitrary
        // future routes): use the API's `direction=` filter — the BVG
        // backend already knows the line topology, so it returns only
        // trips that actually pass the destination. No classifier table
        // needed, route works correctly in any direction.
        let isConfiguredForwardRoute =
            fromStopId == configuration.originStopId &&
            toStopId == configuration.destinationStopId

        if isConfiguredForwardRoute {
            return try await fetchForwardWithBridges(
                fromStopId: fromStopId,
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

    // MARK: - Forward route (configured Alex → Ostkreuz)

    private func fetchForwardWithBridges(
        fromStopId: String,
        maxResults: Int
    ) async throws -> [SBahnDeparture] {
        let origin = try await client.fetchSuburbanDepartures(stopId: fromStopId)
        let originTripIds = Set(origin.compactMap(\.tripId))

        let classified: [(TransitDeparture, SBahnClassification)] = origin.compactMap { dep in
            let cls = SBahnClassifier.classify(
                line: dep.line,
                direction: dep.direction,
                configuration: configuration
            )
            guard cls != .west && cls != .unknown else { return nil }
            return (dep, cls)
        }

        let needsBridge = classified.contains { $0.1.needsBridge }
        let pools: [SBahnTransferStop: [TransitDeparture]] = needsBridge
            ? try await fetchTransferPools()
            : [:]

        let resolved: [SBahnDeparture] = classified.compactMap { dep, cls in
            if cls.needsBridge {
                let inputs = SBahnBridgeResolver.Inputs(
                    shortDeparture: dep,
                    transferOptions: cls.transferOptions,
                    pools: pools,
                    alexTripIds: originTripIds,
                    configuration: configuration
                )
                guard let bridge = SBahnBridgeResolver.resolve(inputs) else { return nil }
                return Self.makeDeparture(from: dep, bridge: bridge)
            } else {
                return Self.makeDeparture(from: dep, bridge: nil)
            }
        }

        return Array(
            resolved
                .sorted { $0.plannedWhen < $1.plannedWhen }
                .prefix(max(maxResults, 0))
        )
    }

    // MARK: - Reverse / arbitrary route (server-side direction filter)

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

    private func fetchTransferPools() async throws -> [SBahnTransferStop: [TransitDeparture]] {
        // Fetch every configured transfer stop in parallel via async let.
        // Today the configuration has exactly Ostbahnhof + Warschauer; the
        // structure makes adding a third stop a one-line change.
        async let ostbf: [TransitDeparture] = {
            guard let id = configuration.transferStopIds[.ostbahnhof] else { return [] }
            return try await client.fetchSuburbanDepartures(stopId: id)
        }()
        async let warsch: [TransitDeparture] = {
            guard let id = configuration.transferStopIds[.warschauer] else { return [] }
            return try await client.fetchSuburbanDepartures(stopId: id)
        }()
        return try await [
            .ostbahnhof: ostbf,
            .warschauer: warsch,
        ]
    }

    private static func makeDeparture(
        from dep: TransitDeparture,
        bridge: BridgeHint?
    ) -> SBahnDeparture {
        let id = dep.tripId ?? "\(dep.line)-\(dep.plannedWhen.timeIntervalSince1970)"
        return SBahnDeparture(
            id: id,
            line: dep.line,
            direction: dep.direction,
            plannedWhen: dep.plannedWhen,
            when: dep.when,
            bridge: bridge
        )
    }
}
