import SwiftUI

struct AppChipView: View {
    let styled: StyledExerciseField
    var content: String? = nil

    var body: some View {
        if let chip = styled.style.display.chip {
            AppChip(
                text: content ?? styled.fullText,
                fontColor: chip.labelColor,
                backgroundColor: chip.backgroundColor,
                size: chip.size,
                icon: chip.icon
            )
        } else {
            EmptyView()
        }
    }
}
