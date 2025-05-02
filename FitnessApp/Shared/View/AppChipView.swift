import SwiftUI

struct AppChipView: View {
    let styled: StyledExerciseField
    var content: String? = nil
    let onTap: (() -> Void)?
    
    init(styled: StyledExerciseField, content: String? = nil, onTap: (() -> Void)? = nil) {
        self.styled = styled
        self.content = content
        self.onTap = onTap
    }
    
    var body: some View {
        if let chip = styled.style.display.chip {
            AppChip(
                text: content ?? styled.fullText,
                fontColor: chip.labelColor,
                backgroundColor: chip.backgroundColor,
                size: chip.size,
                icon: chip.icon,
                onTap: onTap
            )
        } else {
            EmptyView()
        }
    }
}
