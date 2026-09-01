import SwiftUI
import FitnessCore
import FitnessResources

/// One weight or rep increase: the level reached, how it was earned, and the two
/// sessions that bracket it.
///
/// Takes no "has weight" flag. `PhaseValue` carries which dimension changed, so
/// the tile cannot be handed a weight and told to render reps — the mismatch that
/// printed "0 kg" on bodyweight exercises.
public struct WeightPhaseTileView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    public let phase: WeightPhase

    public init(phase: WeightPhase) {
        self.phase = phase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(verbatim: number(of: phase.value))
                    .font(AppStyle.Font.cardBoldTitle)
                    .foregroundColor(appColorTheme.accent.glow)
                unitLabel(for: phase.value, uppercased: true)
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(appColorTheme.accent.glow)
            }

            Text(AppText.analyticsReachedInDays(count: phase.daysToReach))
                .font(AppStyle.Font.cardSmallMedium)
                .foregroundColor(.white.opacity(0.6))

            Text(AppText.analyticsWithWorkoutCount(count: phase.workoutsToReach))
                .font(AppStyle.Font.cardSmallMedium)
                .foregroundColor(AppStyle.Color.white)

            // Separates the summary above from the two sessions that bracket the
            // increase, which are a different kind of statement.
            Rectangle()
                .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.hairlineDivider))
                .frame(height: 1)
                .padding(.vertical, 2)

            phaseRow(
                label: Text(AppText.analyticsPreviousWorkout),
                endpoint: phase.previousSession,
                markerColor: AppStyle.Color.gray,
                showsConnector: true
            )

            phaseRow(
                label: Text(AppText.analyticsIncreased),
                // The session that first reached the new level, expressed the
                // same way as the one before it so the two can be compared at a
                // glance.
                endpoint: PhaseEndpoint(
                    value: phase.value,
                    setsReps: phase.startSetsReps,
                    date: phase.startDate
                ),
                // The accent marks where the increase landed; the row above it
                // stays neutral, so the eye goes to the new value first.
                markerColor: appColorTheme.accent.glow,
                showsConnector: false
            )
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(AppStyle.Opacity.subtleBackground))
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile)
                .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile))
    }

    /// One point on the increase's timeline: a marker, a heading, the level with
    /// the sets it was moved for, and the date spelled out.
    ///
    /// Both ends share this. They used to differ — a `mappin`/`flag` glyph with
    /// sets and date crammed onto one line — and the shorthand was denser than it
    /// was informative. Only the marker colour distinguishes them now.
    private func phaseRow(
        label: Text,
        endpoint: PhaseEndpoint,
        markerColor: Color,
        showsConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 0) {
                // Same ring geometry the idle card's play button draws, so every
                // circular marker on the cards reads as one family.
                Circle()
                    .strokeBorder(markerColor, lineWidth: AppStyle.Layout.idlePlayRingWidth)
                    .frame(width: 14, height: 14)

                if showsConnector {
                    // Runs down to the row below, so the two points read as a
                    // timeline rather than two unrelated entries.
                    Rectangle()
                        .fill(AppStyle.Color.gray)
                        .frame(width: AppStyle.Layout.idlePlayRingWidth)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                label
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(AppStyle.Color.white)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: number(of: endpoint.value))
                        .font(AppStyle.Font.cardValueBold)
                        .foregroundColor(AppStyle.Color.white)
                    unitLabel(for: endpoint.value, uppercased: false)
                        .font(AppStyle.Font.cardSmallMedium)
                        .foregroundColor(AppStyle.Color.white)
                    Text(verbatim: "·")
                        .font(AppStyle.Font.cardSmallMedium)
                        .foregroundColor(.white.opacity(0.4))
                    Text(verbatim: endpoint.setsReps)
                        .font(AppStyle.Font.cardSmallMedium)
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(verbatim: spelledOutDate(endpoint.date))
                    .font(AppStyle.Font.chartAxisSmall)
                    .foregroundColor(.white.opacity(0.4))
            }
            // The tile is one column of a scrolling row, so it is never as wide
            // as its content would like. Scaling keeps each line on one line
            // instead of wrapping into the next.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func number(of value: PhaseValue) -> String {
        switch value {
        case let .weight(weight):
            return WeightFormatter.format(weight, locale: locale)
        case let .reps(reps):
            return "\(reps)"
        }
    }

    /// The header shouts its unit, the timeline rows state it quietly.
    @ViewBuilder
    private func unitLabel(for value: PhaseValue, uppercased: Bool) -> some View {
        switch value {
        case .weight:
            Text(verbatim: uppercased ? "KG" : "kg")
        case .reps:
            uppercased ? Text(AppText.exerciseReps) : Text(AppText.exerciseRepsLowercase)
        }
    }

    /// Spelled out rather than numeric — "Aug 25", not "25.08".
    private func spelledOutDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().locale(locale))
    }
}
