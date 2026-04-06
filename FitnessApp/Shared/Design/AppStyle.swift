import SwiftUI

enum AppStyle {
    enum Padding {
        static let horizontal: CGFloat = 18
        static let screenHorizontal: CGFloat = 15
        static let card: CGFloat = 16
        static let titleTop: CGFloat = 8
        static let titleBottom: CGFloat = 17
        static let activeCardIconOverflow: CGFloat = 20
        static let titleBottomBeforeActiveCard: CGFloat = titleBottom - activeCardIconOverflow
    }

    enum Layout {
        static let cardHorizontalPadding: CGFloat = 16
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let bottomBarButton: CGFloat = 12
        static let editPickerViewButton: CGFloat = 12
        static let defaultButton: CGFloat = 12
        static let sheet: CGFloat = 22
    }

    enum Font {
        static let navigationHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        static let cardHeadline = SwiftUI.Font.system(size: 18, weight: .bold)
        static let regularChip = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)

        static let analyticsExerciseTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let analyticsExerciseData = SwiftUI.Font.system(size: 16, weight: .semibold)

        static let categorySelectionNameFont = SwiftUI.Font.system(size: 20, weight: .semibold)

        static let tileLabel = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let tileValue = SwiftUI.Font.system(size: 16, weight: .medium)
        static let sectionTitle = SwiftUI.Font.system(size: 18, weight: .medium)
        static let numberPadKey = SwiftUI.Font.system(size: 24, weight: .medium)
        static let chartLabel = SwiftUI.Font.system(size: 10, weight: .regular)
        static let pickerAction = SwiftUI.Font.system(size: 14, weight: .regular)

        static let calendarHeader = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let calendarSubheader = SwiftUI.Font.system(size: 12, weight: .medium)
        static let calendarDay = SwiftUI.Font.system(size: 14, weight: .regular)
        static let calendarDayBold = SwiftUI.Font.system(size: 14, weight: .bold)
        static let dayChipLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        static let dayChipNumber = SwiftUI.Font.system(size: 13, weight: .regular)
        static let dayChipNumberBold = SwiftUI.Font.system(size: 13, weight: .bold)
        static let detailCategory = SwiftUI.Font.system(size: 15, weight: .bold)
        static let detailExercise = SwiftUI.Font.system(size: 14, weight: .medium)
        static let detailBadge = SwiftUI.Font.system(size: 14, weight: .bold)
        static let detailCaption = SwiftUI.Font.system(size: 12, weight: .medium)
        static let streakLabel = SwiftUI.Font.system(size: 11, weight: .medium)
        static let streakValue = SwiftUI.Font.system(size: 16, weight: .bold)
    }

    enum Color {
        static let backgroundColor = SwiftUI.Color(hex: "#0A090E")

        static let primaryButton = green

        static let exerciseCardBackground = SwiftUI.Color(hex: "#232227")
        static let chipsBackground = grayDark

        static let white = SwiftUI.Color.white
        static let black = SwiftUI.Color.black
        static let yellow = SwiftUI.Color.yellow

        static let gray = SwiftUI.Color(hex: "#4D4E53")
        static let grayDark = SwiftUI.Color(hex: "#383838")

        static let greenBlack = SwiftUI.Color(hex: "#022123")
        static let greenDark = SwiftUI.Color(hex: "#013334")

        static let green = SwiftUI.Color(hex: "#088177")
        static let greenLight = SwiftUI.Color(hex: "#7EBBAF")
        static let greenGlow = SwiftUI.Color(hex: "#3CC8A6")

        static let sheetBackground = SwiftUI.Color(hex: "#222025")
        static let sheetInputBackground = SwiftUI.Color(hex: "#141518")
        static let metricChipBackground = SwiftUI.Color(hex: "#100F15")
        static let progressTrack = SwiftUI.Color(hex: "#0A2726")
        static let numberPadGray = SwiftUI.Color(hex: "#555555")
        static let trainingAccent = SwiftUI.Color(hex: "#077484")
    }

    enum Opacity {
        static let overlayBackdrop: Double = 0.55
        static let subtleBackground: Double = 0.06
        static let subtleStroke: Double = 0.15
        static let grabberHandle: Double = 0.35
    }
}
