import SwiftUI
import FitnessCore
import FitnessResources
#if canImport(UIKit)
import UIKit
#endif

public struct WorkoutPickerView: View {
    @State private var selectionState = WorkoutPickerSelectionState()

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
                Text(AppText.workoutSelect)
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 20)
                    .accessibilityIdentifier(WorkoutPickerIDs.overlay)

                ZStack {
                    Picker(
                        AppText.workoutSingular,
                        selection: Binding(
                            get: { selectionState.selectedWorkout },
                            set: { selectionState.select($0) }
                        )
                    ) {
                        ForEach(workouts, id: \.id) { workout in
                            Text(workout.name)
                                .font(AppStyle.Font.numberPadKey)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.leading, 5)
                                .tag(workout as Workout?)
                        }
                    }
                    .allowsHitTesting(true)
                    .accessibilityIdentifier(WorkoutPickerIDs.wheel)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            confirmSelection()
                        }
                    )

                    HStack {
                        Spacer()
                        Button {
                            confirmSelection()
                        } label: {
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
                        .accessibilityIdentifier(WorkoutPickerIDs.confirmButton)
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
            selectionState.select(currentWorkout)
        }
        .onChange(of: currentWorkout) { _, newWorkout in
            selectionState.select(newWorkout)
        }
    }

    /// Both the selected wheel row and arrow use this confirmation gate. The
    /// picker's `TapGesture` fails when the user drags, so wheel scrolling
    /// updates only local selection while a discrete tap confirms it.
    private func confirmSelection() {
        guard let workout = selectionState.confirm() else { return }

        onSelect(workout)
#if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }
}

/// Local presentation state for the workout wheel. Selection changes and
/// confirmation are deliberately separate: wheel drags update only the local
/// selection, while a row tap or the arrow confirms the current selection.
/// The gate also prevents fast double confirmation.
struct WorkoutPickerSelectionState {
    private(set) var selectedWorkout: Workout?
    private(set) var hasConfirmedSelection = false

    mutating func select(_ workout: Workout?) {
        selectedWorkout = workout
    }

    mutating func confirm() -> Workout? {
        guard !hasConfirmedSelection,
              let workout = selectedWorkout else {
            return nil
        }

        selectedWorkout = workout
        hasConfirmedSelection = true
        return workout
    }
}
