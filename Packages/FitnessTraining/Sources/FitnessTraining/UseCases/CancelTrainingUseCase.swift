import Foundation

@MainActor
public struct CancelTrainingUseCase {

    nonisolated public init() {}

    public func execute(activeSetViewModel: ActiveSetViewModel) {
        activeSetViewModel.cancelActiveSet()
    }
}
