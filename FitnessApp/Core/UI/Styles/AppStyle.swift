import SwiftUI

enum AppStyle {
    enum Color {
        static let white = SwiftUI.Color.white
        static let whiteLite = SwiftUI.Color.white.opacity(0.2)
        static let purple = SwiftUI.Color(hex: "#A485FD")
        static let purpleLight = SwiftUI.Color(hex: "#E5D8FF")
        static let purpleDark = SwiftUI.Color(hex: "#9575F4")
    }
    
    enum Layout {
        enum Card {
            enum Content {
                static let steigendWidth: CGFloat = 120
                static let setsRepsWidth: CGFloat = 100
                static let setsRepsHeight: CGFloat = 60
                static let weightWidth: CGFloat = 120
                static let weightHeight: CGFloat = 100
                static let spacing: CGFloat = 12
            }
            
            static let contentPadding = EdgeInsets(
                top: 12,
                leading: 12,
                bottom: 12,
                trailing: 12
            )
            static let margin: CGFloat = 16
        }
    }
    
    enum CornerRadius {
        static let card: CGFloat = 16
        static let button: CGFloat = 8
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
    
    enum Padding {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 12
    }
    
    enum Dimensions {
        static let chipHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 44
        static let iconSize: CGFloat = 24
    }
    
    enum Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
    }
} 