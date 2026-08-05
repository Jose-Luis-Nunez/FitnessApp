import Foundation

// MARK: - Domain

public struct CachedSBahnDepartures: Codable, Equatable, Sendable {
    public let departures: [SBahnDeparture]
    public let savedAt: Date

    public init(departures: [SBahnDeparture], savedAt: Date) {
        self.departures = departures
        self.savedAt = savedAt
    }
}

// MARK: - Protocol

public protocol SBahnDeparturesCaching: Sendable {
    func load(fromStopId: String, toStopId: String) -> CachedSBahnDepartures?
    func save(fromStopId: String, toStopId: String, departures: [SBahnDeparture])
}

// MARK: - UserDefaults Implementation

/// Persists the last successful API result per `(from, to)` tuple. The card
/// restores it immediately after launch or a direction change while a
/// user-initiated request loads fresh data. The payload is bounded to four
/// departures plus bridge hints, so UserDefaults is sufficient.
public final class SBahnDeparturesCache: SBahnDeparturesCaching, @unchecked Sendable {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load(fromStopId: String, toStopId: String) -> CachedSBahnDepartures? {
        let key = Self.key(from: fromStopId, to: toStopId)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(CachedSBahnDepartures.self, from: data)
    }

    public func save(fromStopId: String, toStopId: String, departures: [SBahnDeparture]) {
        let key = Self.key(from: fromStopId, to: toStopId)
        let payload = CachedSBahnDepartures(departures: departures, savedAt: Date())
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func key(from: String, to: String) -> String {
        "sbahn.cache.\(from).\(to)"
    }
}
