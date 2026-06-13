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
    /// trips that have a verified standalone (Origin ≠ Alex) bridge candidate
    /// at the transfer station.
    public let bridge: BridgeHint?
    /// Estimated arrival at the user's destination.
    /// - east-direct: planned departure + configured travel time.
    /// - east-short with bridge: bridge departure + (configured travel-to-
    ///   destination minus origin → transfer-stop travel).
    /// `nil` for trips on routes without a configured travelToDestination
    /// (e.g. arbitrary fallback routes via the API direction filter).
    public let arrivalAtDestination: Date?

    public init(
        id: String,
        line: String,
        direction: String,
        plannedWhen: Date,
        when: Date,
        bridge: BridgeHint? = nil,
        arrivalAtDestination: Date? = nil
    ) {
        self.id = id
        self.line = line
        self.direction = direction
        self.plannedWhen = plannedWhen
        self.when = when
        self.bridge = bridge
        self.arrivalAtDestination = arrivalAtDestination
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
///   the standalone requirement — must NOT be a station that Alex is on the
///   route from. Surfaced in the row-tap detail view so the user can confirm.
public struct BridgeHint: Equatable, Sendable, Codable {
    public let transferStation: String
    public let bridgeLine: String
    public let bridgeDeparture: Date
    public let bridgeDirection: String
    public let bridgeOriginStation: String?
    /// tripId of the bridge train. Used by the service to fetch the
    /// bridge's stopovers and derive the user's arrival at destination.
    public let bridgeTripId: String?

    public init(
        transferStation: String,
        bridgeLine: String,
        bridgeDeparture: Date,
        bridgeDirection: String,
        bridgeOriginStation: String? = nil,
        bridgeTripId: String? = nil
    ) {
        self.transferStation = transferStation
        self.bridgeLine = bridgeLine
        self.bridgeDeparture = bridgeDeparture
        self.bridgeDirection = bridgeDirection
        self.bridgeOriginStation = bridgeOriginStation
        self.bridgeTripId = bridgeTripId
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
        case .invalidURL: return "Invalid URL."
        case .network: return "Network unreachable."
        case .decoding: return "Could not read the response."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .serverError: return "BVG server unreachable."
        }
    }
}
