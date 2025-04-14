import SwiftUI

struct FitnessCard<Content: View>: View {
    // MARK: - Properties
    let style: CardStyle
    let content: Content
    
    // MARK: - Initialization
    init(
        style: CardStyle = .primary,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.content = content()
    }
    
    // MARK: - Body
    var body: some View {
        content
            .padding()  // Inner padding for content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style.borderColor, lineWidth: 1.5)  // Increased line width
            )
            .padding(.horizontal)  // Outer padding for the entire card
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .contentShape(Rectangle()) // Ensures the entire card is tappable
    }
}

// MARK: - Card Style
extension FitnessCard {
    enum CardStyle {
        case primary
        case completed
        case inactive
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return Color(hex: "#4A2FAF")  // Sehr dunkles Lila
            case .completed:
                return Color(hex: "#8B6FE0")  // Mittleres Lila
            case .inactive:
                return Color(hex: "#2A1B66")  // Noch dunkleres Lila
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary:
                return Color.white.opacity(0.3)  // Increased opacity
            case .completed:
                return Color.white.opacity(0.4)  // Increased opacity
            case .inactive:
                return Color.white.opacity(0.2)  // Increased opacity
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FitnessCard {
            Text("Primary Card")
                .foregroundColor(.white)
        }
        
        FitnessCard(style: .completed) {
            Text("Completed Card")
                .foregroundColor(.white)
        }
        
        FitnessCard(style: .inactive) {
            Text("Inactive Card")
                .foregroundColor(.gray)
        }
    }
    .padding()
} 
