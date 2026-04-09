import SwiftUI

struct ChipIcon {
    let image: Image
    let color: Color?
    let size: AppChipSize

    init(image: String, color: Color, size: AppChipSize = .regular) {
        self.image = Image(image)
        self.color = color
        self.size = size
    }

    init(image: String, size: AppChipSize = .regular) {
        self.image = Image(image)
        self.color = nil
        self.size = size
    }

    init(systemName: String, color: Color, size: AppChipSize = .regular) {
        self.image = Image(systemName: systemName)
        self.color = color
        self.size = size
    }

    @ViewBuilder
    var view: some View {
        if let color {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(color)
        } else {
            image
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return 16
        case .regular: return 20
        case .large: return 24
        case .extraLarge: return 70
        case .wide: return 52
        }
    }
}
