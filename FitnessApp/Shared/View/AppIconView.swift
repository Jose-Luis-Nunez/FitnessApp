import SwiftUI

struct AppIconView: View {
    let styled: StyledExerciseField

    var body: some View {
        if let iconStyle = styled.style.display.icon {
            iconStyle.icon.image
                .resizable()
                .scaledToFit()
                .frame(
                    width: iconStyle.frame?.width,
                    height: iconStyle.frame?.height
                )
                .offset(iconStyle.offset ?? .zero)
        } else {
            EmptyView()
        }
    }
}
