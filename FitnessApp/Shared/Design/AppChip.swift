import SwiftUI

struct AppChip: View {
    let text: String
    let icon: Image?
    let backgroundColor: Color
    let foregroundColor: Color

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                icon
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            Text(text)
                .font(AppStyle.Font.chip)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}
