import SwiftUI
import FitnessStorage

public struct WorkoutDropdownView: View {
    @ObservedObject public var workoutStorage: WorkoutStorageService
    @EnvironmentObject private var overlayState: UIOverlayState

    public var titleFont: Font

    public init(
        workoutStorage: WorkoutStorageService = .shared,
        titleFont: Font = AppStyle.Font.navigationHeadline
    ) {
        self.workoutStorage = workoutStorage
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
