import SwiftUI

struct WorkoutPickerView: View {
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel
    @EnvironmentObject private var overlayState: UIOverlayState
    @State private var selectedWorkout: Workout?
    
    private let storageService = WorkoutStorageService.shared
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.4))
                )
            
            VStack(spacing: 16) {
                // Title
                Text("Select Workout")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Native iOS Picker with overlay arrow
                ZStack {
                    Picker("Workout", selection: $selectedWorkout) {
                        ForEach(storageService.workouts, id: \.id) { workout in
                            Text(workout.name)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.leading, 5)
                                .tag(workout as Workout?)
                        }
                    }
                    .allowsHitTesting(true)
                    
                    // Arrow overlay on the right side
                    HStack {
                        Spacer()
                        Button(action: {
                            if let workout = selectedWorkout {
                                selectWorkout(workout)
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                overlayState.showWorkoutDropdown = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.black)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                    .allowsHitTesting(true)
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

            }
        }
        .frame(width: 320, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .onAppear {
            selectedWorkout = storageService.currentWorkout
        }
        .onChange(of: storageService.currentWorkout) { _, newWorkout in
            selectedWorkout = newWorkout
        }
    }
    
    private func selectWorkout(_ workout: Workout) {
        viewModel.selectWorkout(workout)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    

}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var viewModel = MuscleCategorySelectionViewModel()
        @StateObject private var overlayState = UIOverlayState()
        
        var body: some View {
            ZStack {
                AppStyle.Color.backgroundColor.ignoresSafeArea()
                
                WorkoutPickerView(viewModel: viewModel)
                    .environmentObject(overlayState)
            }
        }
    }
    
    return PreviewWrapper()
}
