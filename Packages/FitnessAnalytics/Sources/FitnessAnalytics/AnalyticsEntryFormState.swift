import Foundation
import FitnessCore

struct AnalyticsSetInput: Identifiable, Equatable {
    let id: UUID
    var weight: Double
    var reps: Int
    var side: ExerciseSide?
    var logicalSetIndex: Int?

    init(
        id: UUID = UUID(),
        weight: Double,
        reps: Int,
        side: ExerciseSide? = nil,
        logicalSetIndex: Int? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.side = side
        self.logicalSetIndex = logicalSetIndex
    }
}

/// Owns the editable analytics draft independently from the SwiftUI sheet.
///
/// Keeping grouping and mutation rules here prevents the manual-entry UI from
/// becoming a second source of bilateral business logic.
struct AnalyticsEntryFormState: Equatable {
    var sets: [AnalyticsSetInput]

    init(exercise: Exercise, existingEntry: AnalyticsEntry?) {
        if let existingEntry {
            sets = existingEntry.setProgress.map {
                AnalyticsSetInput(
                    id: $0.id,
                    weight: $0.weight,
                    reps: $0.currentReps,
                    side: $0.side,
                    logicalSetIndex: $0.logicalSetIndex
                )
            }
        } else if exercise.executionMode == .bilateral {
            sets = exercise.trainingSteps.map {
                AnalyticsSetInput(
                    weight: exercise.weight,
                    reps: exercise.reps,
                    side: $0.side,
                    logicalSetIndex: $0.logicalSetIndex
                )
            }
        } else {
            sets = [
                AnalyticsSetInput(weight: exercise.weight, reps: exercise.reps)
            ]
        }
    }

    var isBilateral: Bool {
        BilateralSetGrouping.groups(for: progress) != nil
    }

    var logicalSetIndices: [Int] {
        Array(Set(sets.compactMap(\.logicalSetIndex))).sorted()
    }

    func isSaveDisabled(hasWeight: Bool) -> Bool {
        hasWeight
            ? sets.contains { $0.weight == 0 || $0.reps == 0 }
            : sets.contains { $0.reps == 0 }
    }

    mutating func appendSet(defaultWeight: Double, defaultReps: Int) {
        guard isBilateral else {
            sets.append(
                AnalyticsSetInput(weight: defaultWeight, reps: defaultReps)
            )
            return
        }

        let logicalIndex = (logicalSetIndices.max() ?? -1) + 1
        sets.append(contentsOf: ExerciseSide.allCases.map {
            AnalyticsSetInput(
                weight: defaultWeight,
                reps: defaultReps,
                side: $0,
                logicalSetIndex: logicalIndex
            )
        })
    }

    mutating func removePhysicalSet(at index: Int) {
        guard sets.indices.contains(index) else { return }
        sets.remove(at: index)
    }

    mutating func removeLogicalSet(at logicalSetIndex: Int) {
        sets.removeAll { $0.logicalSetIndex == logicalSetIndex }
    }

    func index(logicalSetIndex: Int, side: ExerciseSide) -> Int? {
        sets.firstIndex {
            $0.logicalSetIndex == logicalSetIndex && $0.side == side
        }
    }

    func makeEntry(exerciseId: UUID, date: Date) -> AnalyticsEntry {
        AnalyticsEntry(
            exerciseId: exerciseId,
            date: date,
            setProgress: progress
        )
    }

    private var progress: [SetProgress] {
        sets.map {
            SetProgress(
                id: $0.id,
                status: .completedDone,
                currentReps: $0.reps,
                weight: $0.weight,
                side: $0.side,
                logicalSetIndex: $0.logicalSetIndex
            )
        }
    }
}
