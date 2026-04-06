import SwiftUI

struct WorkoutDropdownView: View {
    @ObservedObject var workoutStorage: WorkoutStorageService = .shared
    @EnvironmentObject private var overlayState: UIOverlayState

    var titleFont: Font = AppStyle.Font.navigationHeadline

    var body: some View {
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

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var overlayState = UIOverlayState()
        
        var body: some View {
            ZStack {
                AppStyle.Color.backgroundColor.ignoresSafeArea()
                
                VStack {
                    WorkoutDropdownView()
                        .environmentObject(overlayState)
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    return PreviewWrapper()
}
