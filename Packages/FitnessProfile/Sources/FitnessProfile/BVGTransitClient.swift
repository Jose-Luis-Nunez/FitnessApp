import Foundation

// MARK: - Domain Type

/// Single departure as exposed by the transit client. Wraps the public
/// surface of the transport.rest `/stops/{id}/departures` endpoint without
/// leaking the wire-level DTOs.
public struct TransitDeparture: Equatable, Sendable {
    public let tripId: String?
    public let line: String
    public let direction: String
    public let plannedWhen: Date
    public let when: Date

    public init(tripId: String?, line: String, direction: String, plannedWhen: Date, when: Date) {
        self.tripId = tripId
        self.line = line
        self.direction = direction
        self.plannedWhen = plannedWhen
        self.when = when
    }
}

// MARK: - Protocol

public protocol BVGTransitClienting: Sendable {
    /// Fetches the next suburban (S-Bahn) departures from `stopId`.
    ///
    /// When `directionStopId` is provided, the BVG API filters server-side to
    /// trips whose route passes that stop — i.e., only trips that will
    /// actually reach the destination are returned. This is the correct
    /// primitive for "show me trains from A toward B" because the API
    /// already knows the routes (no client-side keyword tables needed).
    ///
    /// When `directionStopId` is nil, all departures regardless of route
    /// are returned — used for the bridge-pool fetches at transfer stops
    /// where the client wants the full pool to apply its own filter.
    func fetchSuburbanDepartures(
        stopId: String,
        directionStopId: String?
    ) async throws -> [TransitDeparture]
}

public extension BVGTransitClienting {
    /// Convenience overload for callers that don't need the direction
    /// filter.
    func fetchSuburbanDepartures(stopId: String) async throws -> [TransitDeparture] {
        try await fetchSuburbanDepartures(stopId: stopId, directionStopId: nil)
    }
}

// MARK: - Implementation

/// Thin HTTP client over `v6.bvg.transport.rest`. Returns domain
/// `TransitDeparture` values rather than raw DTOs, so consumers (the
/// classifier, bridge resolver, and orchestrator) never see wire-level
/// shapes. Error mapping mirrors `BVGTramService`.
public final class BVGTransitClient: BVGTransitClienting, @unchecked Sendable {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(baseURL: String = "https://v6.bvg.transport.rest", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchSuburbanDepartures(
        stopId: String,
        directionStopId: String? = nil
    ) async throws -> [TransitDeparture] {
        var components = URLComponents(string: "\(baseURL)/stops/\(stopId)/departures")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "duration", value: "60"),
            URLQueryItem(name: "results", value: "60"),
            URLQueryItem(name: "suburban", value: "true"),
            URLQueryItem(name: "tram", value: "false"),
            URLQueryItem(name: "subway", value: "false"),
            URLQueryItem(name: "bus", value: "false"),
            URLQueryItem(name: "ferry", value: "false"),
            URLQueryItem(name: "express", value: "false"),
            URLQueryItem(name: "regional", value: "false"),
            URLQueryItem(name: "remarks", value: "false"),
        ]
        if let directionStopId {
            queryItems.append(URLQueryItem(name: "direction", value: directionStopId))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw BVGSBahnError.invalidURL }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw BVGSBahnError.network
        }
        guard let http = response as? HTTPURLResponse else { throw BVGSBahnError.network }
        switch http.statusCode {
        case 200...299: break
        case 429: throw BVGSBahnError.rateLimited
        default: throw BVGSBahnError.serverError
        }

        do {
            let envelope = try decoder.decode(DeparturesEnvelope.self, from: data)
            return envelope.departures.compactMap(Self.map)
        } catch {
            throw BVGSBahnError.decoding
        }
    }

    private static func map(_ dto: DepartureDTO) -> TransitDeparture? {
        guard let line = dto.line?.name, !line.isEmpty,
              let when = dto.when else { return nil }
        return TransitDeparture(
            tripId: dto.tripId,
            line: line,
            direction: dto.direction ?? "",
            plannedWhen: dto.plannedWhen ?? when,
            when: when
        )
    }
}

// MARK: - DTOs (internal to client)

private struct DeparturesEnvelope: Decodable {
    let departures: [DepartureDTO]
}

private struct DepartureDTO: Decodable {
    let tripId: String?
    let direction: String?
    let when: Date?
    let plannedWhen: Date?
    let line: LineDTO?
}

private struct LineDTO: Decodable {
    let name: String?
    let product: String?
}
