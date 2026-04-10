import SwiftUI
import FitnessStorage
import Factory

public struct WorkoutDropdownView: View {
    @Injected(\.workoutStorage) private var workoutStorage
    @Environment(UIOverlayState.self) private var overlayState

    public var titleFont: Font

    public init(
        titleFont: Font = AppStyle.Font.navigationHeadline
    ) {
        self.titleFont = titleFont
    }

    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                overlayState.showWorkoutDropdown.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Text(workoutStorage.currentWorkout?.name ?? "Dein Workout")
                    .font(titleFont)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .foregroundColor(AppStyle.Color.white)
                    .rotationEffect(.degrees(overlayState.showWorkoutDropdown ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: overlayState.showWorkoutDropdown)
            }
        }
    }
}
