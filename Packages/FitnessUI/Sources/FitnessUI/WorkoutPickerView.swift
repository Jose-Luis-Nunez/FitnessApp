import SwiftUI
import FitnessCore
import FitnessStorage
import Factory
#if canImport(UIKit)
import UIKit
#endif

public struct WorkoutPickerView: View {
    @Environment(UIOverlayState.self) private var overlayState
    @State private var selectedWorkout: Workout?

    public var onSelect: (Workout) -> Void

    @Injected(\.workoutStorage) private var storageService

    public init(
        onSelect: ((Workout) -> Void)? = nil
    ) {
        let ws = Container.shared.workoutStorage()
        self.onSelect = onSelect ?? { workout in
            ws.setCurrentWorkout(workout)
        }
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.4))
                )

            VStack(spacing: 16) {
                Text("Select Workout")
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 20)

                ZStack {
                    Picker("Workout", selection: $selectedWorkout) {
                        ForEach(storageService.workouts, id: \.id) { workout in
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
                                    .frame(width: 32, height: 32)

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
}
