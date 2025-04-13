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
        static let title = SwiftUI.Font.system(size: 22, weight: .bold)
        static let label = SwiftUI.Font.system(size: 14, weight: .medium)
        static let value = SwiftUI.Font.system(size: 16, weight: .bold)
        static let subtitle = SwiftUI.Font.system(size: 12, weight: .regular)

        static let chip = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let headlineLarge = SwiftUI.Font.system(size: 28, weight: .bold)
        static let metricValue = SwiftUI.Font.system(size: 24, weight: .semibold)
    }

    enum Color {
        static let cardBackground = SwiftUI.Color(hex: "#A485FD")
        //static let cardBackground = SwiftUI.Color(hex: "#C9B3FF")
        static let chipPurple = SwiftUI.Color(hex: "#E5D8FF")
        static let chipLabelColor = SwiftUI.Color.white
        static let seatChip = SwiftUI.Color(hex: "#9575F4")
    }
}
