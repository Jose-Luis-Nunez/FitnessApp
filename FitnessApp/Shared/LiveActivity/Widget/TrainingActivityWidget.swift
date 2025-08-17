import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.1, *)
struct TrainingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            // Lock Screen presentation
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    // Fallback Links (works iOS 16/17) – opens app and routes via deep link
                    Link(destination: URL(string: "fitnessapp://liveaction?action=less")!) {
                        roundedPill(text: "Less", color: Color.gray.opacity(0.25))
                    }
                    Link(destination: URL(string: "fitnessapp://liveaction?action=done")!) {
                        roundedPill(text: "Done", color: Color.green)
                    }
                    Link(destination: URL(string: "fitnessapp://liveaction?action=more")!) {
                        roundedPill(text: "More", color: Color.gray.opacity(0.25))
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.35))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { _ in
            // Optional: Minimal Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Set") }
                DynamicIslandExpandedRegion(.center) { Text("Training") }
                DynamicIslandExpandedRegion(.trailing) { Text("…") }
            } compactLeading: {
                Text("T")
            } compactTrailing: {
                Text("▶︎")
            } minimal: {
                Text("T")
            }
        }
    }

    @ViewBuilder
    private func roundedPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(color)
            .cornerRadius(14)
    }
}


