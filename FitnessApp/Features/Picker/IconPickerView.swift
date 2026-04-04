import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    let icons: [String]

    private let tileCornerRadius: CGFloat = 10
    private let tileBorderWidth: CGFloat = 1
    private let sheetBackground = Color(hex: "#222025")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select icon")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(icons, id: \.self) { iconName in
                    iconCell(for: iconName)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func iconCell(for iconName: String) -> some View {
        Button(action: { selectedIcon = iconName }) {
            VStack(spacing: 8) {
                Image(iconName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60, alignment: iconAlignment(for: iconName))
                    .clipped()
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(selectedIcon == iconName ? AppStyle.Color.green.opacity(0.1) : sheetBackground)
            .cornerRadius(tileCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: tileCornerRadius)
                    .stroke(selectedIcon == iconName ? AppStyle.Color.green : AppStyle.Color.gray, lineWidth: tileBorderWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: tileCornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func iconAlignment(for iconName: String) -> Alignment {
        // Greift gleiche Logik wie bei MuscleCategoryGroup.iconAlignment (top außer legs -> bottom)
        if iconName.lowercased().contains("leg") { return .bottom }
        return .top
    }
}
