import SwiftUI

private struct IDS {
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    var body: some View {
        NavigationStack {
            List(MuscleCategoryGroup.allCases) { group in
                NavigationLink(destination: MuscleCategoryView(group: group)) {
                    HStack {
                        Text(group.displayName)
                            .font(.headline)
                            .accessibilityIdentifier(IDS.label(for: group))
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(L10n.muscleCategoryMuscleGroupsTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
