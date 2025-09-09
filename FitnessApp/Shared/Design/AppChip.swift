import SwiftUI

enum AppChipSize {
    case small
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
    var borderColor: Color? = nil
    var customHeight: CGFloat? = nil

    init(
        text: String,
        fontColor: Color,
        backgroundColor: Color,
        size: AppChipSize = .regular,
        icon: ChipIcon? = nil,
        onTap: (() -> Void)? = nil,
        borderColor: Color? = nil,
        customHeight: CGFloat? = nil
    ) {
        self.text = text
        self.fontColor = fontColor
        self.backgroundColor = backgroundColor
        self.size = size
        self.icon = icon
        self.onTap = onTap
        self.borderColor = borderColor
        self.customHeight = customHeight
    }

    var body: some View {
        HStack(spacing: 6) {
            icon?.view
            Text(text)
                .font(font)
                .foregroundColor(fontColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(minWidth: fixedWidth)
        .frame(height: fixedHeight)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor ?? .clear, lineWidth: borderColor != nil ? 1 : 0)
        )
        .onTapGesture {
            onTap?()
        }
    }

    private var font: Font {
        switch size {
        case .small, .regular: return AppStyle.Font.regularChip
        case .large: return AppStyle.Font.largeChip
        case .wide: return AppStyle.Font.wideChip
        case .extraLarge: return AppStyle.Font.extraLargeChip
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 4
        case .regular: return 14
        case .large: return 16
        case .wide: return 10
        case .extraLarge: return 16
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small, .regular:return 4
        case .large: return 11
        case .wide: return 11
        case .extraLarge: return 11
        }
    }

    private var fixedHeight: CGFloat {
        if let customHeight = customHeight {
            return customHeight
        }
        switch size {
        case .small, .regular: return 32
        case .large: return 44
        case .wide: return 32
        case .extraLarge: return 70
        }
    }
    
    private var fixedWidth: CGFloat {
        return 80
    }
}
