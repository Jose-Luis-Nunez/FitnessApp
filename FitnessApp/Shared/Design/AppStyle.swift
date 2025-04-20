import SwiftUI

enum AppStyle {
    enum Padding {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 12
    }

    enum CornerRadius {
        static let card: CGFloat = 16
    }

    enum Font {
        static let cardHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        static let regularChip = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let wideChip = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
    }

    enum Color {
        static let white = SwiftUI.Color.white
        static let purpleGrey = SwiftUI.Color(hex: "#544985")
        static let purpleLight = SwiftUI.Color(hex: "#E5D8FF")
        static let purple = SwiftUI.Color(hex: "#9575F4")
        static let purpleDark = SwiftUI.Color(hex: "#291B66")
        static let green = SwiftUI.Color(hex: "#22A49A")
        static let yellow = SwiftUI.Color.yellow
    }
    
    enum Dimensions {
         static let chipHeight: CGFloat = 28
     }
}
