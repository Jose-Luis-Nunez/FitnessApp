import SwiftUI

struct ChipIcon {
    let image: Image
    let color: Color
    let size: AppChipSize

    init(image: String, color: Color, size: AppChipSize = .regular) {
        self.image = Image(image)
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
        case .regular: return 20
        case .large: return 16
        case .wide: return 52
        }
    }
}
