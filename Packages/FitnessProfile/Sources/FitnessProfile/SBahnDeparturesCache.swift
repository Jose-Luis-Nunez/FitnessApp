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

/// Mirrors `TramDeparturesCache`: persist last-successful API result per
/// (from, to) tuple so the offline fallback works after process restart.
/// Payload is small (≤ 6 departures + bridge hints ≈ < 4 KB) so UserDefaults
/// is the right tool.
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
