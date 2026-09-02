import SwiftUI
import FitnessCore
import FitnessResources

/// One completed set: its number, the weight it was moved at, and the reps.
///
/// There is deliberately only one treatment. The tile briefly carried a
/// `compact` / `detail` pair while the idle card and the completed card looked
/// different; both now render the same row, so the variant was removed rather
/// than left behind as an unused branch.
public struct SetTileView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let setNumber: Int
    public let weight: Double
    public let reps: Int
    public let hasWeight: Bool

    public init(setNumber: Int, weight: Double, reps: Int, hasWeight: Bool) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.hasWeight = hasWeight
    }

    private var weightText: String {
        WeightFormatter.format(weight, locale: locale)
    }

    /// Same muted grey as "Details" on the completed card header.
    private var unitColor: Color { AppStyle.Color.idleMetricUnit }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppText.exerciseSetNumberUppercase(number: setNumber))
                .font(AppStyle.Font.cardSmallLabel)
                .foregroundColor(unitColor)

            if hasWeight {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(weightText)
                        .font(AppStyle.Font.setTileValue)
                        .foregroundColor(appColorTheme.accent.light)
                    Text(AppText.unitKilogram)
                        .font(AppStyle.Font.setTileUnit)
                        .foregroundColor(unitColor)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: AppStyle.Layout.setTileValueRowHeight, alignment: .leading)

                repsLine
            } else {
                Text(verbatim: "\(reps)")
                    .font(AppStyle.Font.setTileValue)
                    .foregroundColor(appColorTheme.accent.light)

                Text(AppText.exerciseRepsLowercase)
                    .font(AppStyle.Font.setTileRepsUnit)
                    .foregroundColor(unitColor)
            }
        }
        // The row stretches tiles to its own height, so the stack has to claim
        // that height and centre inside it; at its natural size it hangs from
        // the top edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .tileChrome()
    }

    /// Reps footer for a weighted set.
    ///
    /// One plural-varied string, not a number plus a fixed noun: this line reads
    /// as prose ("1 rep" / "12 reps"), and splitting it dropped the plural rule
    /// so a single-rep set rendered "1 reps". A unit-only plural key is not an
    /// option — `xcstringstool` derives arity from the format specifiers, so a
    /// value without one generates an argument-less symbol that can never select
    /// a plural form.
    private var repsLine: some View {
        Text(AppText.exerciseRepetitionsCount(count: reps))
            .font(AppStyle.Font.setTileReps)
            .foregroundColor(AppStyle.Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: AppStyle.Layout.setTileRepsRowHeight, alignment: .leading)
    }
}
