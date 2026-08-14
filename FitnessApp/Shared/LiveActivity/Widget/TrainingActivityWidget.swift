import SwiftUI
import WidgetKit
import ActivityKit
import FitnessResources

struct TrainingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            // Lock Screen presentation
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: context.state.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    // Fallback Links (works iOS 16/17) – opens app and routes via deep link
                    Link(destination: URL(string: "fitnessapp://liveaction?action=less")!) {
                        roundedPill(text: context.state.localized(AppText.actionLess), color: Color.gray.opacity(0.25))
                    }
                    Link(destination: URL(string: "fitnessapp://liveaction?action=done")!) {
                        roundedPill(text: context.state.localized(AppText.actionDone), color: Color.green)
                    }
                    Link(destination: URL(string: "fitnessapp://liveaction?action=more")!) {
                        roundedPill(text: context.state.localized(AppText.actionMore), color: Color.gray.opacity(0.25))
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.35))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            // Optional: Minimal Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(verbatim: context.state.localized(AppText.liveActivitySet))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.state.localized(AppText.liveActivityTraining))
                }
                DynamicIslandExpandedRegion(.trailing) { Text(verbatim: "…") }
            } compactLeading: {
                Text(verbatim: "T")
            } compactTrailing: {
                Text(verbatim: "▶︎")
            } minimal: {
                Text(verbatim: "T")
            }
        }
    }

    @ViewBuilder
    private func roundedPill(text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(color)
            .cornerRadius(14)
    }
}
