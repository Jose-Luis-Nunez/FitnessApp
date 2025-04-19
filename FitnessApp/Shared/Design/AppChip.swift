import SwiftUI

struct ChipIcon {
    let image: Image
    let color: Color
    let size: AppChipSize

    init(image: Image, color: Color, size: AppChipSize = .regular) {
        self.image = image
        self.color = color
        self.size = size
    }

    init(systemName: String, color: Color, size: AppChipSize = .regular) {
        self.image = Image(systemName: systemName)
        self.color = color
        self.size = size
    }
    
    @ViewBuilder
    var view: some View {
        image
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .foregroundStyle(color)
    }

    private var iconSize: CGFloat {
        switch size {
        case .regular: return 14
        case .large: return 16
        case .wide: return 52
        }
    }
}

struct AppChip: View {
    let text: String
    let fontColor: Color
    let backgroundColor: Color
    var size: AppChipSize = .regular
    let icon: ChipIcon?


    var body: some View {
        HStack(spacing: 6) {
            icon?.view
            Text(text)
                .font(font)
                .foregroundColor(fontColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
    
    private var font: Font {
        switch size {
        case .regular: return AppStyle.Font.regularChip
        case .large: return AppStyle.Font.largeChip
        case .wide: return AppStyle.Font.regularChip
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 10
        case .large: return 16
        case .wide: return 10
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return 4
        case .large: return 11
        case .wide: return 11

        }
    }
}

enum AppChipSize {
    case regular
    case large
    case wide
}
