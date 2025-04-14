import SwiftUI

struct FitnessButton: View {
    // MARK: - Properties
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    @Environment(\.isEnabled) private var isEnabled
    
    // MARK: - Initialization
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(style.foregroundColor(isEnabled: isEnabled))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(style.backgroundColor(isEnabled: isEnabled))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Button Style
extension FitnessButton {
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        
        func backgroundColor(isEnabled: Bool) -> Color {
            switch self {
            case .primary:
                return isEnabled ? AppStyle.Color.purpleDark : AppStyle.Color.purpleDark.opacity(0.5)
            case .secondary:
                return isEnabled ? AppStyle.Color.whiteLite : AppStyle.Color.whiteLite.opacity(0.5)
            case .destructive:
                return isEnabled ? Color.red : Color.red.opacity(0.5)
            }
        }
        
        func foregroundColor(isEnabled: Bool) -> Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary:
                return AppStyle.Color.purpleDark
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FitnessButton("Primary Button") {}
        FitnessButton("Secondary Button", style: .secondary) {}
        FitnessButton("Destructive Button", style: .destructive) {}
        FitnessButton("Disabled Button") {}
            .disabled(true)
    }
    .padding()
} 
