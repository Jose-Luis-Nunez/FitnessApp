import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

/// The one look for the controls that float over the training artwork: the
/// timer pill and the Quick-Done disc. A near-black fill and nothing else — no
/// rim, no glow, no material, no gradient. The mint of the arc and the bolt
/// is the only colour, so the surfaces stay neutral and let it read.
enum TrainingDialSurface {
    /// The Quick-Done disc. No rim: the fill alone separates it from the
    /// artwork, and a hairline made the controls read as framed buttons.
    static func background(diameter: CGFloat) -> some View {
        fill(Circle())
            .frame(width: diameter, height: diameter)
    }

    /// The same surface on any shape: the timer pill is a capsule of it.
    static func fill<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(AppStyle.Color.trainingDialDisc)
            .opacity(AppStyle.Opacity.trainingDialDisc)
    }
}

/// Timer and Cancel as one upright pill: a small ring with the elapsed time
/// in it, a hairline divider, and Cancel below. The ring's mint arc fills once
/// per minute and starts over — it is a seconds hand, not a countdown; the
/// digits carry the total.
struct TrainingTimerPill: View {
    var viewModel: ActiveSetViewModel
    let width: CGFloat
    let onCancel: () -> Void

    private var seconds: Int { max(viewModel.timerSeconds, 0) }

    private var minuteProgress: Double {
        Self.minuteProgress(seconds: seconds)
    }

    /// Fraction of the current minute that has elapsed, in `0..<1`.
    static func minuteProgress(seconds: Int) -> Double {
        Double(max(seconds, 0) % 60) / 60
    }

    var body: some View {
        VStack(spacing: AppStyle.Layout.trainingDialPillSpacing) {
            ring

            Rectangle()
                .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.trainingDialDivider))
                .frame(height: 1)
                .padding(.horizontal, AppStyle.Layout.trainingDialPillDividerInset)

            Button(action: onCancel) {
                Text(AppText.trainingCancel)
                    .font(AppStyle.Font.trainingDialCancelLabel)
                    .foregroundColor(AppStyle.Color.idleMetricLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.trainingDialPillCancelHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(FitnessCore.TrainingIDs.cancelTraining)
        }
        .padding(.vertical, AppStyle.Layout.trainingDialPillVerticalPadding)
        .frame(width: width)
        .background {
            TrainingDialSurface.fill(Capsule())
        }
    }

    private var ring: some View {
        let ringSize = width - AppStyle.Layout.trainingDialPillRingInset * 2
        return ZStack {
            // No darker well behind the ring: the arc sits straight on the
            // capsule so the pill reads as one surface.
            Circle()
                .trim(from: 0, to: minuteProgress)
                .stroke(
                    AppStyle.Color.trainingDialAccent,
                    style: StrokeStyle(
                        lineWidth: AppStyle.Layout.trainingDialProgressWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .padding(AppStyle.Layout.trainingDialProgressWidth / 2)
                // Animate the sweep forward only. At the minute boundary the
                // value drops from ~1 to 0; animating that would unwind the
                // arc counter-clockwise for a second, so it snaps instead.
                .animation(
                    minuteProgress == 0 ? nil : .linear(duration: 1),
                    value: minuteProgress
                )

            Text(verbatim: seconds.formattedAsTimer)
                .font(AppStyle.Font.trainingDialPillTimer)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, AppStyle.Layout.trainingDialProgressWidth * 2)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: seconds.formattedAsTimer))
    }
}

/// The Quick-Done dial below the timer: completes the whole exercise in one
/// go. Lives in this column rather than in the Less/Done/More bar so the three
/// dials share one trailing edge.
struct TrainingQuickDoneDial: View {
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                TrainingDialSurface.background(diameter: diameter)

                Image(systemName: "bolt.fill")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: AppStyle.Layout.trainingDialQuickDoneIconSize,
                        height: AppStyle.Layout.trainingDialQuickDoneIconSize
                    )
                    .foregroundColor(AppStyle.Color.trainingDialAccent)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.accessibilityQuickDone)
        .accessibilityIdentifier(TrainingIDs.quickDoneButton)
    }
}
