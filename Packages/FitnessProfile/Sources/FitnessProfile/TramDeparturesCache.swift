import Foundation

// MARK: - Domain

public struct CachedDepartures: Codable, Equatable, Sendable {
    public let departures: [TramDeparture]
    public let savedAt: Date

    public init(departures: [TramDeparture], savedAt: Date) {
        self.departures = departures
        self.savedAt = savedAt
    }
}

// MARK: - Protocol

public protocol TramDeparturesCaching: Sendable {
    func load(fromStopId: String, toStopId: String, line: String) -> CachedDepartures?
    func save(fromStopId: String, toStopId: String, line: String, departures: [TramDeparture])
}

// MARK: - UserDefaults Implementation

/// Persists the most recent successful API response per (line, from, to) tuple so the
/// view can fall back to it when the BVG endpoint is unreachable. Values are tiny
/// (≤ 3 departures × 2 directions ≈ < 2 KB) so UserDefaults is the right tool here —
/// no SwiftData / file IO complexity, survives app restart, mirrors `ProfileStore`.
public final class TramDeparturesCache: TramDeparturesCaching, @unchecked Sendable {
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

    public func load(fromStopId: String, toStopId: String, line: String) -> CachedDepartures? {
        let key = Self.key(line: line, from: fromStopId, to: toStopId)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(CachedDepartures.self, from: data)
    }

    public func save(fromStopId: String, toStopId: String, line: String, departures: [TramDeparture]) {
        let key = Self.key(line: line, from: fromStopId, to: toStopId)
        let payload = CachedDepartures(departures: departures, savedAt: Date())
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func key(line: String, from: String, to: String) -> String {
        "tram.cache.\(line).\(from).\(to)"
    }
}
