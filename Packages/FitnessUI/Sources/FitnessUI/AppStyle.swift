import SwiftUI

public enum AppStyle {
    public enum Padding {
        public static let horizontal: CGFloat = 18
        public static let screenHorizontal: CGFloat = 15
        public static let card: CGFloat = 16
        public static let titleTop: CGFloat = 8
        public static let titleBottom: CGFloat = 17
        public static let activeCardIconOverflow: CGFloat = 20
        public static let titleBottomBeforeActiveCard: CGFloat = titleBottom - activeCardIconOverflow
    }

    public enum Layout {
        public static let cardHorizontalPadding: CGFloat = 16
        public static let chipHeight: CGFloat = 32
        public static let activeCardContentHeight: CGFloat = 80
        public static let activeCardMaxWidth: CGFloat = 400
        public static let categoryIconSize: CGFloat = 50
        public static let checkmarkSize: CGFloat = 36
        public static let playButtonSize: CGFloat = 36
        public static let playIconSize: CGFloat = 16
        public static let completedBarWidth: CGFloat = 8
        public static let setRowBadgeSize: CGFloat = 26
        public static let analyticsImageSize: CGFloat = 60
        public static let seatIconSize: CGFloat = 22
        public static let analyticsEntryIconSize: CGFloat = 24
        public static let separatorHeight: CGFloat = 28
        public static let doneButtonWidth: CGFloat = 80
        public static let doneButtonHeight: CGFloat = 28
    }

    public enum CornerRadius {
        public static let card: CGFloat = 16
        public static let bottomBarButton: CGFloat = 12
        public static let editPickerViewButton: CGFloat = 12
        public static let defaultButton: CGFloat = 12
        public static let sheet: CGFloat = 22
        public static let tile: CGFloat = 10
        public static let timerCard: CGFloat = 12
    }

    public enum Font {
        public static let navigationHeadline = SwiftUI.Font.system(size: 28, weight: .bold)
        public static let cardHeadline = SwiftUI.Font.system(size: 18, weight: .bold)
        public static let regularChip = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let largeChip = SwiftUI.Font.system(size: 24, weight: .semibold)
        public static let defaultFont = SwiftUI.Font.system(size: 12, weight: .semibold)
        public static let bottomBarButtons = SwiftUI.Font.system(size: 16, weight: .semibold)

        public static let analyticsExerciseTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let analyticsExerciseData = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let analyticsHeadline = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let analyticsBigNumber = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let analyticsAxis = SwiftUI.Font.system(size: 9, weight: .medium)

        public static let categorySelectionNameFont = SwiftUI.Font.system(size: 20, weight: .semibold)
        public static let categoryTileTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let categoryTileCount = SwiftUI.Font.system(size: 16, weight: .black)
        public static let categoryTileBadge = SwiftUI.Font.system(size: 14, weight: .heavy)
        public static let categoryTileProgress = SwiftUI.Font.system(size: 12, weight: .heavy)

        public static let tileLabel = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let tileValue = SwiftUI.Font.system(size: 16, weight: .medium)
        public static let sectionTitle = SwiftUI.Font.system(size: 18, weight: .medium)
        public static let sectionHeadline = SwiftUI.Font.system(size: 18, weight: .semibold)
        public static let numberPadKey = SwiftUI.Font.system(size: 24, weight: .medium)
        public static let numberPadDisplay = SwiftUI.Font.system(size: 32, weight: .regular)
        public static let numberPadSymbol = SwiftUI.Font.system(size: 24, weight: .regular)
        public static let chartLabel = SwiftUI.Font.system(size: 10, weight: .regular)
        public static let chartAxisSmall = SwiftUI.Font.system(size: 10, weight: .medium)
        public static let pickerAction = SwiftUI.Font.system(size: 14, weight: .regular)

        public static let cardBoldTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        public static let cardSmallBold = SwiftUI.Font.system(size: 12, weight: .bold)
        public static let cardSmallLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        public static let cardTinyLabel = SwiftUI.Font.system(size: 9, weight: .regular)
        public static let cardValueBold = SwiftUI.Font.system(size: 16, weight: .bold)
        public static let cardSmallMedium = SwiftUI.Font.system(size: 11, weight: .bold)
        public static let metricLabel = SwiftUI.Font.system(size: 11, weight: .medium)

        public static let iconSymbol = SwiftUI.Font.system(size: 20, weight: .semibold)

        public static let calendarHeader = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let calendarSubheader = SwiftUI.Font.system(size: 12, weight: .medium)
        public static let calendarDay = SwiftUI.Font.system(size: 14, weight: .regular)
        public static let calendarDayBold = SwiftUI.Font.system(size: 14, weight: .bold)
        public static let dayChipLabel = SwiftUI.Font.system(size: 10, weight: .semibold)
        public static let dayChipNumber = SwiftUI.Font.system(size: 13, weight: .regular)
        public static let dayChipNumberBold = SwiftUI.Font.system(size: 13, weight: .bold)
        public static let detailCategory = SwiftUI.Font.system(size: 15, weight: .bold)
        public static let detailExercise = SwiftUI.Font.system(size: 14, weight: .medium)
        public static let detailBadge = SwiftUI.Font.system(size: 14, weight: .bold)
        public static let detailCaption = SwiftUI.Font.system(size: 12, weight: .medium)
        public static let streakLabel = SwiftUI.Font.system(size: 11, weight: .medium)
        public static let streakValue = SwiftUI.Font.system(size: 16, weight: .bold)
    }

    public enum Color {
        public static let backgroundColor = SwiftUI.Color(hex: "#0A090E")

        public static let primaryButton = green

        public static let exerciseCardBackground = SwiftUI.Color(hex: "#232227")
        public static let chipsBackground = grayDark

        public static let white = SwiftUI.Color.white
        public static let black = SwiftUI.Color.black
        public static let yellow = SwiftUI.Color.yellow

        public static let gray = SwiftUI.Color(hex: "#4D4E53")
        public static let grayDark = SwiftUI.Color(hex: "#383838")

        public static let greenBlack = SwiftUI.Color(hex: "#022123")
        public static let greenDark = SwiftUI.Color(hex: "#013334")

        public static let green = SwiftUI.Color(hex: "#088177")
        public static let greenLight = SwiftUI.Color(hex: "#7EBBAF")
        public static let greenGlow = SwiftUI.Color(hex: "#3CC8A6")

        public static let sheetBackground = SwiftUI.Color(hex: "#222025")
        public static let sheetInputBackground = SwiftUI.Color(hex: "#141518")
        public static let metricChipBackground = SwiftUI.Color(hex: "#100F15")
        public static let progressTrack = SwiftUI.Color(hex: "#0A2726")
        public static let numberPadGray = SwiftUI.Color(hex: "#555555")
        public static let trainingAccent = SwiftUI.Color(hex: "#077484")
    }

    public enum Opacity {
        public static let overlayBackdrop: Double = 0.55
        public static let subtleBackground: Double = 0.06
        public static let subtleStroke: Double = 0.15
        public static let grabberHandle: Double = 0.35
    }

    public enum Shadow {
        public static let cardColor = SwiftUI.Color.black.opacity(0.2)
        public static let cardRadius: CGFloat = 5
        public static let cardY: CGFloat = 2
    }

    public enum DeviceLayout {
        public enum SizeClass {
            case compact
            case regular
            case large
            case extraLarge
        }

        public static var current: SizeClass {
            #if canImport(UIKit)
            let width = UIScreen.main.bounds.width
            if width >= 430 { return .extraLarge }
            if width > 400 { return .large }
            if width > 375 { return .regular }
            return .compact
            #else
            return .regular
            #endif
        }

        public static var cardSpacing: CGFloat {
            current == .compact ? 6 : 8
        }

        public static var cardPadding: CGFloat {
            switch current {
            case .extraLarge, .large: return 8
            case .regular: return 6
            case .compact: return 4
            }
        }

        public static var analyticsButtonWidth: CGFloat {
            switch current {
            case .extraLarge: return 80
            case .large: return 70
            case .regular: return 65
            case .compact: return 62
            }
        }

        public static var chipWidthVertical: CGFloat {
            current == .extraLarge ? 71 : 63
        }

        public static var iconContainerWidth: CGFloat {
            current == .extraLarge ? 82 : 72
        }

        public static var exerciseIconSize: CGFloat {
            current == .extraLarge ? 108 : 98
        }

        public static var analyticsToIconSpacing: CGFloat {
            switch current {
            case .extraLarge: return 12
            case .large: return 8
            case .regular: return 6
            case .compact: return 4
            }
        }

        public static var setRowWeightMinWidth: CGFloat {
            current == .compact ? 50 : 60
        }

        public static var setRowRepsMinWidth: CGFloat {
            current == .compact ? 110 : 120
        }

        public static var isExtraLarge: Bool {
            current == .extraLarge
        }

        public static var trainingSessionSpacing: CGFloat {
            switch current {
            case .compact: return 8
            case .regular: return 10
            case .large: return 12
            case .extraLarge: return 16
            }
        }

        public static var timerFontSize: CGFloat {
            switch current {
            case .compact: return 15
            case .regular: return 16
            case .large: return 18
            case .extraLarge: return 20
            }
        }
    }

    public enum Blur {
        public static let iconGlow: CGFloat = 12
    }
}
