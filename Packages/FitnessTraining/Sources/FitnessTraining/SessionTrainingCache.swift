import Foundation
import Observation
import FitnessCore

public protocol SessionTrainingCaching: AnyObject {
    var activeSetVMs: [MuscleCategoryGroup: ActiveSetViewModel] { get set }
    func viewModel(for group: MuscleCategoryGroup) -> ActiveSetViewModel
}

@Observable
@MainActor
public final class SessionTrainingCache: SessionTrainingCaching {
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
