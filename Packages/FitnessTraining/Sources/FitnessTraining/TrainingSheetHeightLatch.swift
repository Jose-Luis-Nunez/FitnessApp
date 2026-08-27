import CoreGraphics

/// Holds the training sheet's measured height for the sheets that must occupy
/// the same frame — the feedback sheet and the Less/More picker.
///
/// The rule is not "remember the last measurement". A measurement is only valid
/// while nothing is presented over the training sheet: an overlay can change
/// what the sheet itself lays out, and a measurement taken then describes a
/// sheet whose size is a side effect of the very overlay being sized from it.
/// The original case was the bottom action bar leaving the layout during a set
/// edit — that particular one is fixed at the source now, but the feedback sheet
/// and the exercise form still sit over this sheet, so the guard stays.
///
/// A value type in this package rather than private state in the app target's
/// view, so the rule can be tested without a UI host — the app target has no
/// unit-test target.
public struct TrainingSheetHeightLatch: Equatable, Sendable {
    /// Used until the first valid measurement arrives. Close to the real
    /// height, so a sheet presented before the first layout pass is not wildly
    /// wrong.
    public static let fallbackHeight: CGFloat = 380

    public private(set) var height: CGFloat

    public init(height: CGFloat = Self.fallbackHeight) {
        self.height = height
    }

    /// Records a measurement of the training sheet.
    ///
    /// Ignored while an overlay is presented, and ignored when non-positive: a
    /// collapsed or not-yet-laid-out sheet reports 0, and clamping that to a
    /// hairline would make every sibling sheet collapse with it. Keeping the
    /// last known good height is the useful answer in both cases.
    public mutating func record(_ measured: CGFloat, overlayPresented: Bool) {
        guard !overlayPresented, measured > 0 else { return }
        height = measured
    }
}
