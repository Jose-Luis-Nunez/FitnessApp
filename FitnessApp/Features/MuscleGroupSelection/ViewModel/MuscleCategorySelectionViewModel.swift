import Foundation

final class MuscleCategorySelectionViewModel: ObservableObject {
    @Published var groups: [MuscleCategoryGroup] = MuscleCategoryGroup.allCases
}
