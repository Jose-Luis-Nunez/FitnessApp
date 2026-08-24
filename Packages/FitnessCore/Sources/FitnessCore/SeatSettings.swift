import Foundation

/// The seat ("machine") settings of an exercise.
///
/// Multiple seat positions are persisted packed into the single
/// `Exercise.seatSetting` string (no separate schema) — this type is the one
/// place that knows that packing format and the policy limits around it, so the
/// editor and the idle card never duplicate `split`/`join`/`prefix` logic.
public struct SeatSettings: Equatable, Sendable {
    /// Maximum number of seat positions a user can store for one exercise.
    public static let editableLimit = 4
    /// Maximum number of seat positions a compact card surface renders. Stored
    /// positions beyond this limit stay available in the editor but are not
    /// shown on the card.
    public static let cardDisplayLimit = 2
    /// Trimmed, non-empty seat positions in display order.
    public private(set) var positions: [String]

    public init(positions: [String]) {
        self.positions = SeatSettings.clean(positions)
    }

    /// Decode the packed `Exercise.seatSetting` value into individual positions.
    /// Tolerant of surrounding whitespace; empty/whitespace-only parts are
    /// dropped.
    public init(encoded: String?) {
        self.positions = SeatSettings.clean(
            (encoded ?? "").split(separator: Self.separator).map(String.init)
        )
    }

    /// The positions a compact card shows, capped at `cardDisplayLimit`.
    /// Empty when nothing is stored — callers decide how to render that.
    public var cardPositions: [String] {
        Array(positions.prefix(SeatSettings.cardDisplayLimit))
    }

    /// Pack the positions back into the stored format, or `nil` when there is
    /// nothing to store (so callers can keep `seatSetting` optional).
    public var encoded: String? {
        positions.isEmpty ? nil : positions.joined(separator: Self.joinSeparator)
    }

    // MARK: - Packing format (single source of truth)

    /// Parsing splits on the bare slash so stored values are read back
    /// regardless of the spaces around it.
    private static let separator: Character = "/"
    /// Pretty-printing / storage joins with spaces around the slash.
    private static let joinSeparator = " / "

    private static func clean(_ raw: [String]) -> [String] {
        raw.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
