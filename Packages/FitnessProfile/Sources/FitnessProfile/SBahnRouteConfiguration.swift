import Foundation

// MARK: - Transfer Stops

/// Stations on the Berlin Stadtbahn between Alex and Ostkreuz where a user
/// can disembark a non-direct trip and pick up a connecting S-Bahn that
/// continues to the destination. Same physical stops in either direction.
public enum SBahnTransferStop: String, CaseIterable, Sendable {
    case ostbahnhof
    case warschauer

    public var displayName: String {
        switch self {
        case .ostbahnhof: return "S Ostbahnhof"
        case .warschauer: return "S+U Warschauer Str."
        }
    }
}

// MARK: - Route Configuration

/// All tunable values driving S-Bahn routing for one specific (origin →
/// destination) pair. Naming is direction-neutral: a configuration always
/// describes "trips going from origin to destination" — the keyword tables
/// classify directions in terms of THIS specific routing, not in absolute
/// east/west.
public struct SBahnRouteConfiguration: Sendable {

    // MARK: Stop IDs (transport.rest BVG `id` field)

    public let originStopId: String
    public let destinationStopId: String
    public let transferStopIds: [SBahnTransferStop: String]

    // MARK: Travel times (origin → transfer stop)

    /// How long it takes a normal-service trip from `originStopId` to
    /// arrive at each transfer stop. Used to compute the bridge-search
    /// window. Direction-specific because Stadtbahn travel time differs
    /// (Ostkreuz → Warschauer is 2 stops/~2min reversed; Alex → Warschauer
    /// is the same 2 stops/~6min total because there are intermediate stops).
    public let travelTimes: [SBahnTransferStop: TimeInterval]

    /// Bridge departure must fall within this window after user's arrival
    /// at the transfer stop. Beyond this, waiting at origin is faster.
    public let bridgeWindow: TimeInterval

    /// How long a normal-service trip takes from origin to destination
    /// directly. Used to estimate user-facing arrival time at destination
    /// (`SBahnDeparture.arrivalAtDestination`). For trips that need a
    /// bridge, the arrival is derived as bridge.departure + (this value
    /// minus origin → transfer-stop travel).
    public let travelToDestination: TimeInterval

    // MARK: Classification tables (direction-neutral)

    /// Direction-string fragments that indicate a trip will pass
    /// `destinationStopId` on its route. In forward (Alex→Ostkreuz) these
    /// are east-of-Ostkreuz terminus names. In reverse (Ostkreuz→Alex)
    /// they're west-of-Alex terminus names.
    public let passesDestinationKeywords: [String]

    /// Direction-string fragments for trips going AWAY from the destination
    /// (the "wrong direction"). Filtered out before any bridge search.
    public let wrongDirectionKeywords: [String]

    /// Lines that bypass the destination by branching off at a transfer stop
    /// (e.g. S9 forward direction goes south at Warschauer toward BER).
    /// Empty in directions where no line bypasses (e.g. reverse direction).
    /// Keyed by line name (`"S9"` etc.).
    public let bypassLineKeywords: [String: [String]]

    public init(
        originStopId: String,
        destinationStopId: String,
        transferStopIds: [SBahnTransferStop: String],
        travelTimes: [SBahnTransferStop: TimeInterval],
        bridgeWindow: TimeInterval,
        travelToDestination: TimeInterval,
        passesDestinationKeywords: [String],
        wrongDirectionKeywords: [String],
        bypassLineKeywords: [String: [String]]
    ) {
        self.originStopId = originStopId
        self.destinationStopId = destinationStopId
        self.transferStopIds = transferStopIds
        self.travelTimes = travelTimes
        self.bridgeWindow = bridgeWindow
        self.travelToDestination = travelToDestination
        self.passesDestinationKeywords = passesDestinationKeywords
        self.wrongDirectionKeywords = wrongDirectionKeywords
        self.bypassLineKeywords = bypassLineKeywords
    }

    // MARK: - Default keyword tables (Berlin Stadtbahn)

    /// Stadtbahn east-of-Ostkreuz terminus keywords (S3/S5/S7/S75 going
    /// past Ostkreuz to Erkner / Strausberg / Ahrensfelde / Wartenberg / …).
    /// Used as `passesDestinationKeywords` in forward direction and as
    /// `wrongDirectionKeywords` in reverse direction.
    static let eastOfOstkreuzKeywords: [String] = [
        "Erkner", "Friedrichshagen", "Köpenick", "Karlshorst",
        "Ahrensfelde", "Lichtenberg", "Mahlsdorf", "Strausberg",
        "Hoppegarten", "Wuhletal", "Wartenberg",
    ]

    /// Stadtbahn west-of-Alex terminus keywords (S3/S5/S7 going past Alex
    /// to Spandau / Westkreuz / Charlottenburg / Potsdam / …).
    /// Used as `passesDestinationKeywords` in reverse direction and as
    /// `wrongDirectionKeywords` in forward direction.
    static let westOfAlexKeywords: [String] = [
        "Westkreuz", "Spandau", "Charlottenburg", "Grunewald", "Potsdam",
        "Tiergarten", "Zoologischer", "Hauptbahnhof", "Bellevue",
        "Friedrichstr", "Hackesch", "Jannowitz",
    ]

    /// S9 bypass terminus keywords (south branch at Warschauer toward BER).
    /// Only meaningful in forward direction — S9 from Ostkreuz back to
    /// Alex isn't a thing because S9 doesn't pass Ostkreuz at all.
    static let s9BypassSouthKeywords: [String] = [
        "Flughafen", "BER", "Schönefeld", "Schöneweide",
        "Treptow", "Plänterwald", "Adlershof", "Grünau",
        "Spindlersfeld", "Baumschulenweg",
    ]

    // MARK: - Static configurations

    /// Forward Stadtbahn route: S+U Alexanderplatz → S Ostkreuz.
    public static let standardBerlinForward = SBahnRouteConfiguration(
        originStopId: "900100003",
        destinationStopId: "900120003",
        transferStopIds: [
            .ostbahnhof: "900120005",
            .warschauer: "900120004",
        ],
        travelTimes: [
            .ostbahnhof: 4 * 60.0,
            .warschauer: 6 * 60.0,
        ],
        bridgeWindow: 5 * 60.0,
        travelToDestination: 9 * 60.0,
        passesDestinationKeywords: eastOfOstkreuzKeywords,
        wrongDirectionKeywords: westOfAlexKeywords,
        bypassLineKeywords: ["S9": s9BypassSouthKeywords]
    )

    /// Reverse Stadtbahn route: S Ostkreuz → S+U Alexanderplatz.
    /// Travel times reversed (Warschauer is closer to Ostkreuz than
    /// Ostbahnhof). No bypass line — S9 doesn't connect Ostkreuz to Alex.
    public static let standardBerlinReverse = SBahnRouteConfiguration(
        originStopId: "900120003",
        destinationStopId: "900100003",
        transferStopIds: [
            .ostbahnhof: "900120005",
            .warschauer: "900120004",
        ],
        travelTimes: [
            .warschauer: 2 * 60.0,
            .ostbahnhof: 4 * 60.0,
        ],
        bridgeWindow: 5 * 60.0,
        travelToDestination: 9 * 60.0,
        passesDestinationKeywords: westOfAlexKeywords,
        wrongDirectionKeywords: eastOfOstkreuzKeywords,
        bypassLineKeywords: [:]
    )

    /// Backward-compatible alias used by tests / older callers.
    public static let standardBerlin = standardBerlinForward
}
