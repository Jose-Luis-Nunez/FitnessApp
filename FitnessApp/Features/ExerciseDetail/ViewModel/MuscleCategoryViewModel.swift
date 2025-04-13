import Foundation

@MainActor
final class MuscleCategoryViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []
    
    private let group: MuscleCategoryGroup
    private let storage: ExerciseStoring

    init(group: MuscleCategoryGroup, storage: ExerciseStoring = ExerciseStorageService()) {
        self.group = group
        self.storage = storage
        load()
    }

    func add(_ exercise: Exercise) {
        exercises.append(exercise)
        save()
    }

    func delete(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        exercises = storage.load(for: group)
    }

    private func save() {
        storage.save(exercises, for: group)
    }
    
    func updateExercise(_ updated: Exercise) {
        guard let index = exercises.firstIndex(where: { $0.id == updated.id }) else { return }
        exercises[index] = updated
        save()
    }

}
