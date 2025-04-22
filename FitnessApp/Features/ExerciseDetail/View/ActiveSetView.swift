import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(AppStyle.Color.yellow)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<sets, id: \.self) { _ in
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppStyle.Color.purpleDark)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.vertical, 16)
        }
        .frame(height: calculateHeight())
    }
    
    private func calculateHeight() -> CGFloat {
        let iconHeight = 24.0
        let spacing = 16.0
        let verticalPadding = 16.0 * 2
        let totalIconHeight = CGFloat(sets) * iconHeight
        let totalSpacing = CGFloat(max(0, sets - 1)) * spacing
        return totalIconHeight + totalSpacing + verticalPadding
    }
}
