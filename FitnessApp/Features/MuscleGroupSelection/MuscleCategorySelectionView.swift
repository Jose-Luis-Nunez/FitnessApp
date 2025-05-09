import SwiftUI

private struct IDS {
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    @State private var selectedGroup: MuscleCategoryGroup?

    var body: some View {
        VStack {
            List(MuscleCategoryGroup.allCases, id: \.self) { group in
                NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                    Text(group.displayName)
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .padding()
                }
                .listRowBackground(AppStyle.Color.backgroundColor)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationTitle("Muscle Categories")
    }
}
