import Foundation
import SwiftUI

@MainActor
final class ExerciseCardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var exercise: Exercise
    @Published private(set) var isSetInProgress = false
    @Published private(set) var currentSet = 0
    @Published private(set) var isCompleted: Bool
    
    // MARK: - Edit State
    enum EditMode {
        case none
        case seat
        case weight
        case reps
        case sets
        
        var title: String {
            switch self {
            case .seat: return L10n.ExerciseCard.editSeatTitle
            case .weight: return L10n.ExerciseCard.editWeightTitle
            case .sets: return "Sätze ändern"
            case .reps: return "Wiederholungen ändern"
            case .none: return ""
            }
        }
        
        var placeholder: String {
            switch self {
            case .seat: return L10n.ExerciseCard.editSeatPlaceholder
            case .weight: return L10n.ExerciseCard.editWeightPlaceholder
            case .sets: return "Anzahl Sätze"
            case .reps: return "Anzahl Wiederholungen"
            case .none: return ""
            }
        }
        
        var requiresNumericKeyboard: Bool {
            self != .seat
        }
    }
    
    // MARK: - Dependencies
    private let onUpdate: (Exercise) -> Void
    
    // MARK: - Initialization
    init(exercise: Exercise, isCompleted: Bool = false, onUpdate: @escaping (Exercise) -> Void = { _ in }) {
        self.exercise = exercise
        self.isCompleted = isCompleted
        self.onUpdate = onUpdate
    }
    
    // MARK: - Public Interface
    func updateExercise(_ updated: Exercise) {
        self.exercise = updated
        self.isCompleted = updated.isCompleted
        onUpdate(updated)
    }
    
    func updateWeight(_ newValue: Int) {
        let updated = exercise.updating(weight: newValue)
        updateExercise(updated)
    }
    
    func updateReps(_ newValue: Int) {
        let updated = exercise.updating(reps: newValue)
        let finalUpdated = updated.updateCurrentReps(newValue)
        updateExercise(finalUpdated)
    }
    
    func updateSets(_ newValue: Int) {
        let updated = exercise.updating(sets: newValue)
        updateExercise(updated)
        
        if currentSet >= newValue {
            currentSet = max(0, newValue - 1)
        }
    }
    
    func updateSeat(_ newValue: String) {
        let updated = exercise.updating(seatSetting: newValue)
        updateExercise(updated)
    }
    
    func updateCurrentReps(_ newReps: Int) {
        let updated = exercise.updateCurrentReps(newReps)
        updateExercise(updated)
        
        if currentSet >= exercise.sets - 1 {
            let completed = updated.markCompleted()
            updateExercise(completed)
        }
    }
    
    func startSet() {
        isSetInProgress = true
        currentSet += 1
    }
    
    func completeSet() {
        isSetInProgress = false
        
        if currentSet >= exercise.sets - 1 {
            let completed = exercise.markCompleted()
            updateExercise(completed)
        }
    }
    
    func resetProgress() {
        let reset = exercise.reset()
        exercise = reset
        isCompleted = false
        currentSet = 0
        isSetInProgress = false
        onUpdate(reset)
    }
    
    // MARK: - Computed Properties
    var displayColor: Color {
        return isCompleted ? AppStyle.Color.purpleLight : AppStyle.Color.purple
    }
    
    var seatDisplayText: String {
        if let seat = exercise.seatSetting, !seat.isEmpty {
            return "\(L10n.seat): \(seat)"
        } else {
            return L10n.seatOptional
        }
    }
    
    var startButtonTitle: String {
        if exercise.isCompleted {
            return "Start"
        }
        if currentSet == 0 {
            return "Start Sets"
        }
        return "Set \(currentSet + 1) Start"
    }
    
    var canStartNewSet: Bool {
        !exercise.isCompleted && currentSet < exercise.sets
    }
    
    var currentReps: Int {
        exercise.currentReps
    }
    
    var targetReps: Int {
        exercise.reps
    }
    
    var totalSets: Int {
        exercise.sets
    }
    
    var weight: Int {
        exercise.weight
    }
    
    var name: String {
        exercise.name
    }
    
    var weightDisplayText: String {
        "\(weight) \(L10n.ExerciseCard.weightUnit)"
    }
    
    var setsDisplayText: String {
        "\(totalSets)x"
    }
    
    var repsDisplayText: String {
        "\(currentReps)"
    }
    
    // MARK: - Accessibility
    var weightAccessibilityLabel: String {
        "\(weight) Kilogramm"
    }
    
    var setsAccessibilityLabel: String {
        "\(totalSets) Sätze"
    }
    
    var repsAccessibilityLabel: String {
        "\(currentReps) Wiederholungen"
    }
    
    var seatAccessibilityLabel: String {
        "\(L10n.seat) \(seatDisplayText)"
    }
    
    // MARK: - Update Methods
    func getInitialValue(for mode: EditMode) -> String {
        switch mode {
        case .seat:
            return exercise.seatSetting ?? ""
        case .weight:
            return "\(weight)"
        case .sets:
            return "\(totalSets)"
        case .reps:
            return "\(targetReps)"
        case .none:
            return ""
        }
    }
}
