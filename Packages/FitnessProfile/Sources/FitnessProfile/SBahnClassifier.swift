import Foundation

// MARK: - Classification

/// Where an Alex-departure ends up relative to the user's destination
/// (Ostkreuz). Drives whether the trip needs a bridge and which transfer
/// stops are reachable.
public enum SBahnClassification: Equatable, Sendable {
    /// Trip passes through the destination on its normal route. No transfer
    /// needed.
    case eastDirect

    /// Trip terminates at S Ostbahnhof (typical late-evening short-turn).
    /// User must change at Ostbahnhof — Warschauer is not reachable because
    /// the trip ends before it.
    case eastShortOstbahnhof

    /// Trip continues east past Ostbahnhof and Warschauer but branches off
    /// before the destination (e.g. S9 toward BER turns south at
    /// Warschauer). User can change at Ostbahnhof OR Warschauer.
    case eastShortWarschauer

    /// Westbound (Spandau, Charlottenburg, …). Filtered from the result.
    case west

    /// Direction string didn't match any known pattern. Filtered to be
    /// safe rather than show wrong info.
    case unknown

    /// Reachable transfer stops if this classification needs a bridge.
    /// Empty for direct/west/unknown.
    public var transferOptions: [SBahnTransferStop] {
        switch self {
        case .eastDirect, .west, .unknown:
            return []
        case .eastShortOstbahnhof:
            return [.ostbahnhof]
        case .eastShortWarschauer:
            return [.ostbahnhof, .warschauer]
        }
    }

    /// True for non-direct east-bound classifications that need a bridge
    /// resolution before being shown to the user.
    public var needsBridge: Bool {
        !transferOptions.isEmpty
    }
}

// MARK: - Classifier

/// Pure functions that map (line, direction) tuples to classifications.
/// Stateless and configuration-driven; no I/O, no side effects.
public enum SBahnClassifier {

    /// Classifies an Alex-departure based on its line name and the
    /// direction (terminus) string.
    ///
    /// Order matters: westbound first, then short-turns, then S9-bypass,
    /// then east-direct. Unknown patterns return `.unknown` and are
    /// filtered out by the caller.
    public static func classify(
        line: String,
        direction: String,
        configuration config: SBahnRouteConfiguration
    ) -> SBahnClassification {
        if config.westboundKeywords.contains(where: direction.contains) {
            return .west
        }
        if direction.contains("Ostbahnhof") {
            return .eastShortOstbahnhof
        }
        if direction.contains("Warschauer") {
            return .eastShortWarschauer
        }
        if line == "S9", config.eastBypassS9Keywords.contains(where: direction.contains) {
            return .eastShortWarschauer
        }
        if config.eastViaDestinationKeywords.contains(where: direction.contains) {
            return .eastDirect
        }
        return .unknown
    }

    /// Classifies a candidate departure at a transfer stop. Only east-direct
    /// trips that continue to the destination qualify as bridges; trips
    /// that terminate at the transfer stop or earlier are filtered.
    public static func isEastDirectAtTransfer(
        line: String,
        direction: String,
        configuration config: SBahnRouteConfiguration
    ) -> Bool {
        if config.westboundKeywords.contains(where: direction.contains) { return false }
        if direction.contains("Ostbahnhof") { return false }
        if direction.contains("Warschauer") { return false }
        return config.eastViaDestinationKeywords.contains(where: direction.contains)
    }
}
