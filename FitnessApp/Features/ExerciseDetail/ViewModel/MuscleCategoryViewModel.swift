import Foundation
import Combine
import SwiftUI

// MARK: - Exercise State
enum ExerciseState: Equatable {
    case idle
    case setInProgress(exercise: Exercise)
    
    var currentSet: Int {
        switch self {
        case .idle:
            return 0
        case .setInProgress:
            return 1
        }
    }
    
    var isSetInProgress: Bool {
        switch self {
        case .idle:
            return false
        case .setInProgress:
            return true
        }
    }
    
    var currentExercise: Exercise? {
        switch self {
        case .idle:
            return nil
        case .setInProgress(let exercise):
            return exercise
        }
    }
}

// MARK: - ViewModel
@MainActor
final class MuscleCategoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var state: ExerciseState = .idle
    @Published var error: AppError?
    
    // MARK: - Dependencies
    private let group: MuscleCategoryGroup
    private let storage: ExerciseStoring
    private let errorHandler: ErrorHandler
    
    // MARK: - Computed Properties
    var startButtonTitle: String {
        switch state {
        case .idle:
            return "Start Sets"
        case .setInProgress:
            return "Done!"
        }
    }
    
    var activeExercises: [Exercise] {
        exercises.filter { !$0.isCompleted }
    }
    
    var completedExercises: [Exercise] {
        exercises.filter { $0.isCompleted }
    }
    
    // MARK: - Initialization
    init(
        group: MuscleCategoryGroup,
        storage: ExerciseStoring = ExerciseStorageService(),
        errorHandler: ErrorHandler = .shared
    ) {
        self.group = group
        self.storage = storage
        self.errorHandler = errorHandler
        
        // Setup error handling
        errorHandler.addObserver { [weak self] error in
            self?.error = error
        }
        
        // Load exercises
        loadExercises()
    }
    
    deinit {
        errorHandler.removeAllObservers()
    }
    
    // MARK: - Public Interface
    func add(name: String, weight: Int, reps: Int, sets: Int, seat: String?) {
        let exercise = Exercise(
            name: name,
            weight: weight,
            reps: reps,
            sets: sets,
            seatSetting: seat
        )
        
        exercises.append(exercise)
        saveExercises()
    }
    
    func updateExercise(_ updated: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == updated.id }) {
            exercises[index] = updated
            saveExercises()
        }
    }
    
    func startSet(for exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            state = .setInProgress(exercise: exercise)
            saveExercises()
        }
    }
    
    func completeCurrentSet() {
        if case .setInProgress(let exercise) = state {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                let updated = exercise.updateCurrentReps(exercise.currentReps)
                exercises[index] = updated
                
                if updated.isCompleted {
                    state = .idle
                }
                
                saveExercises()
            }
        }
    }
    
    func updateCurrentReps(_ newReps: Int) {
        if case .setInProgress(let exercise) = state {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                let updated = exercise.updateCurrentReps(newReps)
                exercises[index] = updated
                saveExercises()
            }
        }
    }
    
    func resetProgress() {
        exercises = exercises.map { $0.reset() }
        state = .idle
        saveExercises()
    }
    
    // MARK: - Private Methods
    private func loadExercises() {
        do {
            exercises = try storage.load(for: group)
        } catch {
            print("Error loading exercises: \(error)")
            exercises = []
        }
    }
    
    private func saveExercises() {
        do {
            try storage.save(exercises, for: group)
        } catch {
            print("Error saving exercises: \(error)")
        }
    }
}
