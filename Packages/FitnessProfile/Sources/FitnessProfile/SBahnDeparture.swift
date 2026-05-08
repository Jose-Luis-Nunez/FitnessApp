import Foundation

// MARK: - Domain

/// One row in the S-Bahn-Card list. Same shape as `TramDeparture` plus an
/// optional `bridge` hint for trips that don't reach Ostkreuz directly and
/// require a transfer at Ostbahnhof or Warschauer Str.
public struct SBahnDeparture: Equatable, Identifiable, Sendable, Codable {
    public let id: String
    public let line: String
    public let direction: String
    public let plannedWhen: Date
    public let when: Date
    /// `nil` for east-direct trips (no transfer needed). Non-nil for east-short
    /// trips that have a verified eigenständig (Origin ≠ Alex) bridge candidate
    /// at the transfer station.
    public let bridge: BridgeHint?

    public init(
        id: String,
        line: String,
        direction: String,
        plannedWhen: Date,
        when: Date,
        bridge: BridgeHint? = nil
    ) {
        self.id = id
        self.line = line
        self.direction = direction
        self.plannedWhen = plannedWhen
        self.when = when
        self.bridge = bridge
    }

    /// Delay in whole minutes (rounded). Negative = ahead of schedule.
    public var delayMinutes: Int {
        Int((when.timeIntervalSince(plannedWhen) / 60).rounded())
    }
}

/// Routing hint for trips that need a transfer to reach Ostkreuz.
///
/// - `transferStation`: where the user disembarks the Alex-Trip
///   (e.g. "S Ostbahnhof" or "S+U Warschauer Str.")
/// - `bridgeLine`: line of the connecting train (e.g. "S3")
/// - `bridgeDeparture`: when the bridge departs from `transferStation`
/// - `bridgeDirection`: terminus shown by the bridge (e.g. "S Erkner Bhf")
/// - `bridgeOriginStation`: where the bridge trip itself originated. Verifies
///   the eigenständig requirement — must NOT be a station that Alex is on the
///   route from. Surfaced in the row-tap detail view so the user can confirm.
public struct BridgeHint: Equatable, Sendable, Codable {
    public let transferStation: String
    public let bridgeLine: String
    public let bridgeDeparture: Date
    public let bridgeDirection: String
    public let bridgeOriginStation: String?

    public init(
        transferStation: String,
        bridgeLine: String,
        bridgeDeparture: Date,
        bridgeDirection: String,
        bridgeOriginStation: String? = nil
    ) {
        self.transferStation = transferStation
        self.bridgeLine = bridgeLine
        self.bridgeDeparture = bridgeDeparture
        self.bridgeDirection = bridgeDirection
        self.bridgeOriginStation = bridgeOriginStation
    }
}

// MARK: - Errors

public enum BVGSBahnError: LocalizedError, Equatable {
    case invalidURL
    case network
    case decoding
    case rateLimited
    case serverError

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ungültige URL."
        case .network: return "Netzwerk nicht erreichbar."
        case .decoding: return "Antwort konnte nicht gelesen werden."
        case .rateLimited: return "Zu viele Anfragen. Bitte kurz warten."
        case .serverError: return "BVG-Server nicht erreichbar."
        }
    }
}
