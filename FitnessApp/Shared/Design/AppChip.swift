import SwiftUI

enum AppChipSize {
    case regular
    case large
    case wide
    case extraLarge
}

struct AppChip: View {
    let text: String
    let fontColor: Color
    let backgroundColor: Color
    var size: AppChipSize = .regular
    let icon: ChipIcon?
    let onTap: (() -> Void)?
    
    init(
        text: String,
        fontColor: Color,
        backgroundColor: Color,
        size: AppChipSize = .regular,
        icon: ChipIcon? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.fontColor = fontColor
        self.backgroundColor = backgroundColor
        self.size = size
        self.icon = icon
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 6) {
            icon?.view
            Text(text)
                .font(font)
                .foregroundColor(fontColor)
                .lineLimit(1)
                .minimumScaleFactor(1.0)
                .layoutPriority(1)
        }
        .frame(width: 60)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundColor)
        .cornerRadius(12)
        .onTapGesture {
            onTap?()
        }
    }
    
    private var font: Font {
        switch size {
        case .regular: return AppStyle.Font.regularChip
        case .large: return AppStyle.Font.largeChip
        case .wide: return AppStyle.Font.wideChip
        case .extraLarge: return AppStyle.Font.extraLargeChip
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 10
        case .large: return 16
        case .wide: return 10
        case .extraLarge: return 16
        }
    }
    
    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return 4
        case .large: return 11
        case .wide: return 11
        case .extraLarge : return 11
        }
    }
}
