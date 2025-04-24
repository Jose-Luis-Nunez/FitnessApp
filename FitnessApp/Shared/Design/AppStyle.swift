import SwiftUI

enum AppStyle {
    enum Padding {
        static let horizontal: CGFloat = 18
        static let vertical: CGFloat = 12
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let bottomBarButton: CGFloat = 25
    }

    enum Font {
        static let cardHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        static let regularChip = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let wideChip = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)
    }

    enum Color {
        static let backgroundColor = SwiftUI.Color(hex: "#0C403E")
        static let primaryButton = SwiftUI.Color(hex: "#0B3436")
        static let secondaryButton = SwiftUI.Color(hex: "#5CC5BE")

        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let purpleGrey = SwiftUI.Color(hex: "#544985")
        static let purpleLight = SwiftUI.Color(hex: "#E5D8FF")
        static let purple = SwiftUI.Color(hex: "#9575F4")
        static let purpleDark = SwiftUI.Color(hex: "#291B66")
        static let yellow = SwiftUI.Color.yellow
        static let greenBlack = SwiftUI.Color(hex: "#022123")
        static let greenDark = SwiftUI.Color(hex: "#013334")
        static let green = SwiftUI.Color(hex: "#22A49A")
        static let grey = SwiftUI.Color(hex: "#7C6C77")
    }
    
    enum Dimensions {
         static let chipHeight: CGFloat = 28
     }
}
