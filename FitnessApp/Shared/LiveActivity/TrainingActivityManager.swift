import Foundation
import UIKit
import ActivityKit

final class TrainingActivityManager {
    static let shared = TrainingActivityManager()
    private init() {}

    private var activity: Activity<TrainingActivityAttributes>?

    func start(exerciseName: String, totalSets: Int, reps: Int, weight: Double) {
        #if targetEnvironment(simulator)
        print("[LiveActivity] Skipped: Simulator does not support starting Live Activities. Test on a real iPhone.")
        return
        #endif
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            print("[LiveActivity] Skipped: Live Activities are only available on iPhone.")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Disabled in system settings (Settings > Face ID & Passcode > Live Activities).")
            return
        }
        let attributes = TrainingActivityAttributes(id: UUID())
        let content = TrainingActivityAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: 1,
            totalSets: totalSets,
            reps: reps,
            weight: weight,
            isFinished: false
        )
        do {
            activity = try Activity.request(attributes: attributes, contentState: content, pushType: nil)
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func update(exerciseName: String, currentSet: Int, totalSets: Int, reps: Int, weight: Double, isFinished: Bool) {
        guard let activity else { return }
        let content = TrainingActivityAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            reps: reps,
            weight: weight,
            isFinished: isFinished
        )
        Task { await activity.update(using: content) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        self.activity = nil
    }
}


