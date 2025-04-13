import SwiftUI

private struct IDS {
    static func image(for group: MuscleCategoryGroup) -> String { "id_image_\(group.id)" }
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    var body: some View {
        NavigationView {
            List(MuscleCategoryGroup.allCases) { group in
                NavigationLink(destination: MuscleCategoryView(group: group)) {
                    HStack {
                        Image(group.imageName)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier(IDS.image(for: group))

                        Text(group.rawValue)
                            .font(.headline)
                            .accessibilityIdentifier(IDS.label(for: group))
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(L10n.muscleGroups)
        }
    }
}
