import Foundation

// MARK: - Transfer Stops

/// Stations on the Berlin Stadtbahn between Alex and Ostkreuz where a user
/// can disembark a non-direct trip and pick up a connecting S-Bahn that
/// continues to Ostkreuz.
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

/// All tunable values driving S-Bahn routing for a given route. Default is
/// the Alex → Ostkreuz Stadtbahn segment, but the type stays parametric so
/// tests and future routes can supply alternate values.
public struct SBahnRouteConfiguration: Sendable {

    // MARK: Stop IDs (transport.rest BVG `id` field)

    public let originStopId: String
    public let destinationStopId: String
    public let transferStopIds: [SBahnTransferStop: String]

    // MARK: Travel times

    /// Approximate time from `originStopId` to each transfer stop. Used to
    /// compute the bridge-search window after the user disembarks.
    public let travelTimes: [SBahnTransferStop: TimeInterval]

    /// How long after arrival at the transfer stop the bridge departure must
    /// fall. Bridges later than this aren't user-friendly — the user is
    /// better off waiting at origin.
    public let bridgeWindow: TimeInterval

    // MARK: Classification tables

    /// Direction-string fragments that indicate the trip will pass through
    /// `destinationStopId` on the regular Stadtbahn route. Verified against
    /// `/trips/{tripId}?stopovers=true` for S3/S5/S7/S75 lines on the
    /// eastern Berlin S-Bahn segment.
    public let eastViaDestinationKeywords: [String]

    /// S9-specific fragments: trips that go east from origin but branch
    /// south at Warschauer Str. toward BER, bypassing Ostkreuz. Verified
    /// against the actual S9 17:02 Friday stopover list.
    public let eastBypassS9Keywords: [String]

    /// Direction fragments for westbound trips. Filtered out of the result
    /// list before any bridge search.
    public let westboundKeywords: [String]

    public init(
        originStopId: String,
        destinationStopId: String,
        transferStopIds: [SBahnTransferStop: String],
        travelTimes: [SBahnTransferStop: TimeInterval],
        bridgeWindow: TimeInterval,
        eastViaDestinationKeywords: [String],
        eastBypassS9Keywords: [String],
        westboundKeywords: [String]
    ) {
        self.originStopId = originStopId
        self.destinationStopId = destinationStopId
        self.transferStopIds = transferStopIds
        self.travelTimes = travelTimes
        self.bridgeWindow = bridgeWindow
        self.eastViaDestinationKeywords = eastViaDestinationKeywords
        self.eastBypassS9Keywords = eastBypassS9Keywords
        self.westboundKeywords = westboundKeywords
    }

    // MARK: Default — Berlin Stadtbahn Alex → Ostkreuz

    public static let standardBerlin = SBahnRouteConfiguration(
        originStopId: "900100003",       // S+U Alexanderplatz Bhf
        destinationStopId: "900120003",  // S Ostkreuz Bhf
        transferStopIds: [
            .ostbahnhof: "900120005",
            .warschauer: "900120004",
        ],
        travelTimes: [
            .ostbahnhof: 4 * 60.0,
            .warschauer: 6 * 60.0,
        ],
        bridgeWindow: 5 * 60.0,
        eastViaDestinationKeywords: [
            "Erkner", "Friedrichshagen", "Köpenick", "Karlshorst",
            "Ahrensfelde", "Lichtenberg", "Mahlsdorf", "Strausberg",
            "Hoppegarten", "Wuhletal", "Wartenberg",
        ],
        eastBypassS9Keywords: [
            "Flughafen", "BER", "Schönefeld", "Schöneweide",
            "Treptow", "Plänterwald", "Adlershof", "Grünau",
            "Spindlersfeld", "Baumschulenweg",
        ],
        westboundKeywords: [
            "Westkreuz", "Spandau", "Charlottenburg", "Grunewald", "Potsdam",
            "Tiergarten", "Zoologischer", "Hauptbahnhof", "Bellevue",
            "Friedrichstr", "Hackesch", "Jannowitz",
        ]
    )
}
