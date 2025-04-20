import SwiftUI

struct TextView: View {
    let styled: StyledExerciseField
    var content: String? = nil

    var body: some View {
        if let text = styled.style.display.text {
            Text(content ?? text.text)
                .font(text.textFontSize)
                .foregroundColor(text.textColor)
        } else {
            EmptyView()
        }
    }
}
