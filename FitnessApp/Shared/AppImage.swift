import SwiftUI

enum AppImage {
    static let arms = Image("arms")
    static let chest = Image("chest")
    static let back = Image("back")
    static let legs = Image("legs")
    static let abs = Image("abs")

    static func image(for group: MuscleCategoryGroup) -> Image {
        switch group {
        case .arms: return arms
        case .chest: return chest
        case .back: return back
        case .legs: return legs
        case .abs: return abs
        }
    }
}
