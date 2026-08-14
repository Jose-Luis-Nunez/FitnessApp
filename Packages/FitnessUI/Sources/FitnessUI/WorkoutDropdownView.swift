import SwiftUI
import FitnessResources

public struct WorkoutDropdownView: View {
    @Environment(UIOverlayState.self) private var overlayState

    private let workoutName: String?
    private let titleFont: Font

    public init(
        workoutName: String?,
        titleFont: Font = AppStyle.Font.navigationHeadline
    ) {
        self.workoutName = workoutName
        self.titleFont = titleFont
    }

    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                overlayState.showWorkoutDropdown.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Group {
                    if let workoutName {
                        Text(verbatim: workoutName)
                    } else {
                        Text(AppText.workoutFallbackName)
                    }
                }
                    .font(titleFont)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .foregroundColor(AppStyle.Color.white)
                    .rotationEffect(.degrees(overlayState.showWorkoutDropdown ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: overlayState.showWorkoutDropdown)
            }
        }
        .accessibilityIdentifier(WorkoutPickerIDs.dropdown)
    }
}
