import Foundation

class WorkoutStorageService: ObservableObject {
    static let shared = WorkoutStorageService()
    
    @Published var workouts: [Workout] = []
    @Published var currentWorkout: Workout?
    @Published var defaultWorkout: Workout?
    
    private let userDefaults = UserDefaults.standard
    private let workoutsKey = "stored_workouts"
    private let currentWorkoutKey = "current_workout_id"
    private let defaultWorkoutKey = "default_workout_id"
    
    private init() {
        loadWorkouts()
        loadCurrentWorkout()
        loadDefaultWorkout()
        
        // Create default workout if none exist
        if workouts.isEmpty {
            let firstWorkout = Workout(name: "Workout 1")
            workouts.append(firstWorkout)
            currentWorkout = firstWorkout
            defaultWorkout = firstWorkout
            saveWorkouts()
            saveCurrentWorkout()
            saveDefaultWorkout()
        }
    }
    
    // MARK: - Workout Management
    
    func createWorkout(name: String, selectedCategories: Set<MuscleCategoryGroup> = Set(MuscleCategoryGroup.allCases)) -> Workout {
        let newWorkout = Workout(name: name, selectedCategories: selectedCategories)
        workouts.append(newWorkout)
        saveWorkouts()
        return newWorkout
    }
    
    func duplicateWorkout(_ workout: Workout) -> Workout {
        let duplicatedWorkout = workout.copy(withName: "\(workout.name) Copy")
        workouts.append(duplicatedWorkout)
        saveWorkouts()
        
        let exerciseService = ExerciseStorageService()
        for category in workout.selectedCategories {
            let exercises = exerciseService.loadForWorkout(workoutId: workout.id, category: category)
            if !exercises.isEmpty {
                exerciseService.saveForWorkout(exercises, workoutId: duplicatedWorkout.id, category: category)
            }
        }
        
        return duplicatedWorkout
    }
    
    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        
        // If deleted workout was current, switch to first available
        if currentWorkout?.id == workout.id {
            currentWorkout = workouts.first
            saveCurrentWorkout()
        }
        
        saveWorkouts()
    }
    
    func updateWorkout(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            var updatedWorkout = workout
            updatedWorkout.updateLastModified()
            workouts[index] = updatedWorkout
            
            // Update current workout if it's the same
            if currentWorkout?.id == workout.id {
                currentWorkout = updatedWorkout
            }
            
            saveWorkouts()
        }
    }
    
    func setCurrentWorkout(_ workout: Workout) {
        currentWorkout = workout
        saveCurrentWorkout()
    }
    
    func setAsDefaultWorkout(_ workout: Workout) {
        defaultWorkout = workout
        saveDefaultWorkout()
    }
    
    func removeAsDefaultWorkout() {
        defaultWorkout = nil
        userDefaults.removeObject(forKey: defaultWorkoutKey)
    }
    
    func renameWorkout(_ workout: Workout, newName: String) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index].name = newName
            workouts[index].updateLastModified()
            
            if currentWorkout?.id == workout.id {
                currentWorkout = workouts[index]
            }
            
            saveWorkouts()
        }
    }
    
    // MARK: - Exercise Data Management
    
    func updateExerciseData(for workoutId: UUID, key: String, data: Any) {
        if let index = workouts.firstIndex(where: { $0.id == workoutId }) {
            workouts[index].exerciseData[key] = data
            workouts[index].updateLastModified()
            
            if currentWorkout?.id == workoutId {
                currentWorkout = workouts[index]
            }
            
            saveWorkouts()
        }
    }
    
    func getExerciseData(for workoutId: UUID, key: String) -> Any? {
        return workouts.first(where: { $0.id == workoutId })?.exerciseData[key]
    }
    
    // MARK: - Persistence
    
    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            userDefaults.set(encoded, forKey: workoutsKey)
        }
    }
    
    private func loadWorkouts() {
        if let data = userDefaults.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        }
    }
    
    private func saveCurrentWorkout() {
        if let currentWorkout = currentWorkout {
            userDefaults.set(currentWorkout.id.uuidString, forKey: currentWorkoutKey)
        }
    }
    
    private func loadCurrentWorkout() {
        if let currentWorkoutIdString = userDefaults.string(forKey: currentWorkoutKey),
           let currentWorkoutId = UUID(uuidString: currentWorkoutIdString) {
            currentWorkout = workouts.first(where: { $0.id == currentWorkoutId })
        }
    }
    
    private func saveDefaultWorkout() {
        if let defaultWorkout = defaultWorkout {
            userDefaults.set(defaultWorkout.id.uuidString, forKey: defaultWorkoutKey)
        }
    }
    
    private func loadDefaultWorkout() {
        if let defaultWorkoutIdString = userDefaults.string(forKey: defaultWorkoutKey),
           let defaultWorkoutId = UUID(uuidString: defaultWorkoutIdString) {
            defaultWorkout = workouts.first(where: { $0.id == defaultWorkoutId })
        }
    }
} 