import SwiftUI

struct AppChip: View {
    let text: String
    let icon: Image?
    let backgroundColor: Color
    let foregroundColor: Color
    var size: AppChipSize = .regular

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                icon
                    .resizable()
                    .renderingMode(.original)
                    .foregroundColor(foregroundColor)
                    .frame(width: iconSize, height: iconSize)
            }
            Text(text)
                .font(font)
                .foregroundColor(foregroundColor)
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
        case .regular: return AppStyle.Font.chip
        case .large: return AppStyle.Font.metricValue
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .regular: return 12
        case .large: return 16
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return 10
        case .large: return 16
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return 4
        case .large: return 11
        }
    }
}

enum AppChipSize {
    case regular
    case large
}
