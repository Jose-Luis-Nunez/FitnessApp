import SwiftUI

enum AppStyle {
    enum Padding {
        static let horizontal: CGFloat = 18
        static let vertical: CGFloat = 12
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let bottomBarButton: CGFloat = 12
        static let editPickerViewButton: CGFloat = 12
    }

    enum Font {
        static let cardHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        static let regularChip = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let wideChip = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)
    }
    
    enum Color {
        static let backgroundColor = black
        static let exerciseCardBackground = grayDark
        static let exerciseCardDoneBackGround = black
        static let primaryButton = green
        static let secondaryButton = greenLight

        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let yellow = SwiftUI.Color.yellow
        static let gray = SwiftUI.Color.gray
        static let grayDark = SwiftUI.Color(hex: "#1E1E1E")

        static let purpleGrey = SwiftUI.Color(hex: "#544985")
        static let purpleLight = SwiftUI.Color(hex: "#E5D8FF")
        static let purple = SwiftUI.Color(hex: "#9575F4")
        static let purpleDark = SwiftUI.Color(hex: "#291B66")
        
        static let greenBlack = SwiftUI.Color(hex: "#022123")
        static let greenDark = SwiftUI.Color(hex: "#013334")
        
        static let greenLight = SwiftUI.Color(hex: "#7EBBAF")
        static let green = SwiftUI.Color(hex: "#088177")
    }
    
    enum Dimensions {
         static let chipHeight: CGFloat = 28
     }
}
