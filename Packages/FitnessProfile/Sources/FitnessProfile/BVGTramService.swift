import Foundation

// MARK: - Domain

public struct TramDeparture: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let line: String
    public let direction: String
    public let plannedWhen: Date
    public let when: Date

    public init(id: String, line: String, direction: String, plannedWhen: Date, when: Date) {
        self.id = id
        self.line = line
        self.direction = direction
        self.plannedWhen = plannedWhen
        self.when = when
    }

    /// Delay in whole minutes (rounded). Negative means the tram is ahead of schedule.
    public var delayMinutes: Int {
        Int((when.timeIntervalSince(plannedWhen) / 60).rounded())
    }
}

public enum BVGTramError: LocalizedError, Equatable {
    case invalidURL
    case network
    case decoding
    case rateLimited
    case serverError(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .network: return "Network unreachable."
        case .decoding: return "Could not read the response."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .serverError(let statusCode):
            return "Transit service temporarily unavailable (\(statusCode)). Please try again later."
        }
    }
}

// MARK: - Protocol

public protocol BVGTramServicing: Sendable {
    func fetchDepartures(
        fromStopId: String,
        directionStopId: String,
        line: String,
        maxResults: Int
    ) async throws -> [TramDeparture]
}

// MARK: - Service

public final class BVGTramService: BVGTramServicing, @unchecked Sendable {
    private let baseURL: String
    private let transport: BVGHTTPTransport
    private let decoder: JSONDecoder

    public init(baseURL: String = "https://v6.bvg.transport.rest", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.transport = BVGHTTPTransport(session: session)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    init(baseURL: String = "https://v6.bvg.transport.rest", transport: BVGHTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func fetchDepartures(
        fromStopId: String,
        directionStopId: String,
        line: String,
        maxResults: Int = 3
    ) async throws -> [TramDeparture] {
        var components = URLComponents(string: "\(baseURL)/stops/\(fromStopId)/departures")
        components?.queryItems = [
            URLQueryItem(name: "direction", value: directionStopId),
            URLQueryItem(name: "duration", value: "60"),
            URLQueryItem(name: "results", value: "20"),
            URLQueryItem(name: "tram", value: "true"),
            URLQueryItem(name: "suburban", value: "false"),
            URLQueryItem(name: "subway", value: "false"),
            URLQueryItem(name: "bus", value: "false"),
            URLQueryItem(name: "ferry", value: "false"),
            URLQueryItem(name: "express", value: "false"),
            URLQueryItem(name: "regional", value: "false"),
            URLQueryItem(name: "remarks", value: "false")
        ]

        guard let url = components?.url else {
            throw BVGTramError.invalidURL
        }

        let data: Data
        do {
            data = try await transport.data(from: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch BVGHTTPError.rateLimited {
            throw BVGTramError.rateLimited
        } catch BVGHTTPError.httpStatus(let statusCode) {
            throw BVGTramError.serverError(statusCode: statusCode)
        } catch {
            throw BVGTramError.network
        }

        let decoded: DeparturesEnvelope
        do {
            decoded = try decoder.decode(DeparturesEnvelope.self, from: data)
        } catch {
            throw BVGTramError.decoding
        }

        let filtered = decoded.departures
            .compactMap(Self.mapDeparture(_:))
            .filter { $0.line == line }
            .sorted { $0.plannedWhen < $1.plannedWhen }

        return Array(filtered.prefix(max(maxResults, 0)))
    }

    // MARK: - Mapping

    private static func mapDeparture(_ dto: DepartureDTO) -> TramDeparture? {
        guard let name = dto.line?.name, !name.isEmpty else { return nil }
        guard let when = dto.when else { return nil }
        let planned = dto.plannedWhen ?? when
        // tripId can vary; fall back to a deterministic composite so rows stay stable
        // across refreshes.
        let id = dto.tripId ?? "\(name)-\(planned.timeIntervalSince1970)"
        return TramDeparture(
            id: id,
            line: name,
            direction: dto.direction ?? "",
            plannedWhen: planned,
            when: when
        )
    }
}

// MARK: - DTOs

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
