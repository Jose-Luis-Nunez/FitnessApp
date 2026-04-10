import Foundation
import FitnessCore

public protocol SessionTrainingCaching: AnyObject {
    var activeSetVMs: [MuscleCategoryGroup: ActiveSetViewModel] { get set }
    func viewModel(for group: MuscleCategoryGroup) -> ActiveSetViewModel
}

public final class SessionTrainingCache: SessionTrainingCaching {
    public static let shared = SessionTrainingCache()

    public init() {}

    public var activeSetVMs: [MuscleCategoryGroup: ActiveSetViewModel] = [:]

    public func viewModel(for group: MuscleCategoryGroup) -> ActiveSetViewModel {
        if let existing = activeSetVMs[group] {
            return existing
        }
        let vm = ActiveSetViewModel()
        activeSetVMs[group] = vm
        return vm
    }
}
