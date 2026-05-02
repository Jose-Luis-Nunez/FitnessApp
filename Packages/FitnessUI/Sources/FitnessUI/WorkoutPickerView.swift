import SwiftUI
import FitnessCore
#if canImport(UIKit)
import UIKit
#endif

public struct WorkoutPickerView: View {
    @Environment(UIOverlayState.self) private var overlayState
    @State private var selectedWorkout: Workout?

    private let workouts: [Workout]
    private let currentWorkout: Workout?
    private let onSelect: (Workout) -> Void

    public init(
        workouts: [Workout],
        currentWorkout: Workout?,
        onSelect: @escaping (Workout) -> Void
    ) {
        self.workouts = workouts
        self.currentWorkout = currentWorkout
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.overlay, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.overlay, style: .continuous)
                        .fill(Color.gray.opacity(AppStyle.Opacity.fadedOverlay))
                )

            VStack(spacing: 16) {
                Text("Select Workout")
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 20)

                ZStack {
                    Picker("Workout", selection: $selectedWorkout) {
                        ForEach(workouts, id: \.id) { workout in
                            Text(workout.name)
                                .font(AppStyle.Font.numberPadKey)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.leading, 5)
                                .tag(workout as Workout?)
                        }
                    }
                    .allowsHitTesting(true)

                    HStack {
                        Spacer()
                        Button(action: {
                            if let workout = selectedWorkout {
                                onSelect(workout)
#if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                overlayState.showWorkoutDropdown = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: AppStyle.Layout.overlayConfirmButtonSize, height: AppStyle.Layout.overlayConfirmButtonSize)

                                Image(systemName: "arrow.right")
                                    .foregroundColor(AppStyle.Color.black)
                                    .font(AppStyle.Font.bottomBarButtons)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                    .allowsHitTesting(true)
                }
#if os(iOS)
                .pickerStyle(.wheel)
#else
                .pickerStyle(.menu)
#endif
                .frame(height: AppStyle.Layout.workoutPickerWheelHeight)
            }
        }
        .frame(width: AppStyle.Layout.workoutPickerWidth, height: AppStyle.Layout.workoutPickerHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppStyle.CornerRadius.overlay, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.overlay, style: .continuous)
                .strokeBorder(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
        )
        .shadow(color: .black.opacity(AppStyle.Opacity.overlayBackdrop), radius: AppStyle.Shadow.overlayRadius, x: 0, y: AppStyle.Shadow.overlayY)
        .onAppear {
            selectedWorkout = currentWorkout
        }
        .onChange(of: currentWorkout) { _, newWorkout in
            selectedWorkout = newWorkout
        }
    }
}
