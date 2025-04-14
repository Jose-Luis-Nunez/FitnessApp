import SwiftUI

struct FitnessChip: View {
    // MARK: - Properties
    let text: String
    let icon: Image?
    let style: ChipStyle
    let iconColor: Color?
    let size: ChipSize
    
    // MARK: - Initialization
    init(
        _ text: String,
        icon: Image? = nil,
        style: ChipStyle = .primary,
        iconColor: Color? = nil,
        size: ChipSize = .regular
    ) {
        self.text = text
        self.icon = icon
        self.style = style
        self.iconColor = iconColor
        self.size = size
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: size.spacing) {
            if let icon = icon {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.iconSize, height: size.iconSize)
                    .foregroundColor(iconColor ?? style.foregroundColor)
                    .symbolRenderingMode(.monochrome)
                    .imageScale(size.imageScale)
            }
            
            Text(text)
                .font(size.font)
                .fontWeight(size.fontWeight)
                .foregroundColor(style.foregroundColor)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(style.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
    }
}

// MARK: - Chip Style
extension FitnessChip {
    enum ChipStyle {
        case primary
        case secondary
        case highlight
        case custom(background: Color, foreground: Color)
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return AppStyle.Color.purpleDark
            case .secondary:
                return AppStyle.Color.whiteLite
            case .highlight:
                return AppStyle.Color.purple
            case .custom(let background, _):
                return background
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .highlight:
                return .white
            case .secondary:
                return AppStyle.Color.purpleDark
            case .custom(_, let foreground):
                return foreground
            }
        }
    }
}

// MARK: - Chip Size
extension FitnessChip {
    enum ChipSize {
        case regular
        case medium
        case large
        case mediumWide
        
        var iconSize: CGFloat {
            switch self {
            case .regular: return 16
            case .medium: return 24
            case .large: return 32
            case .mediumWide: return 24
            }
        }
        
        var imageScale: Image.Scale {
            switch self {
            case .regular: return .small
            case .medium: return .medium
            case .large: return .large
            case .mediumWide: return .medium
            }
        }
        
        var font: Font {
            switch self {
            case .regular: return .subheadline
            case .medium: return .system(size: 20, weight: .semibold)
            case .large: return .system(size: 25, weight: .bold)
            case .mediumWide: return .system(size: 16, weight: .semibold)
            }
        }
        
        var fontWeight: Font.Weight {
            switch self {
            case .regular: return .medium
            case .medium: return .semibold
            case .large: return .bold
            case .mediumWide: return .semibold
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .regular: return 12
            case .medium: return 16
            case .large: return 10
            case .mediumWide: return 30
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .regular: return 6
            case .medium: return 8
            case .large: return 30
            case .mediumWide: return 8
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .regular: return 4
            case .medium: return 8
            case .large: return 12
            case .mediumWide: return 8
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .regular: return 12
            case .medium: return 16
            case .large: return 20
            case .mediumWide: return 16
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FitnessChip("Primary Chip")
        
        FitnessChip(
            "Secondary Chip",
            icon: Image(systemName: "star.fill"),
            style: .secondary
        )
        
        FitnessChip(
            "Highlight Chip",
            icon: Image(systemName: "bolt.fill"),
            style: .highlight
        )
        
        FitnessChip(
            "Custom Chip",
            icon: Image(systemName: "heart.fill"),
            style: .custom(background: .blue, foreground: .white)
        )
    }
    .padding()
} 
