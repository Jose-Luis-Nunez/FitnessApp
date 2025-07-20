import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    let icons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon wählen")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(icons, id: \.self) { iconName in
                    iconCell(for: iconName)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func iconCell(for iconName: String) -> some View {
        Image(iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .padding(6)
            .background(selectedIcon == iconName ? Color.gray.opacity(0.3) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                selectedIcon = iconName
            }
    }
}
