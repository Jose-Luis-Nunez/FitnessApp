import SwiftUI

private struct IDS {
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()
    @State private var selectedGroup: MuscleCategoryGroup?

    var body: some View {
        VStack {
            List(MuscleCategoryGroup.allCases, id: \.self) { group in
                NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                    HStack {
                        Text(group.displayName)
                            .font(AppStyle.Font.navigationHeadline)
                            .foregroundColor(AppStyle.Color.white)
                        Spacer()
                        if let (total, active) = viewModel.getExerciseCount(for: group) {
                            Text("(\(total)/\(active))")
                                .font(AppStyle.Font.defaultFont)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.leading, 8)
                        } else {
                            Text("(0/0)")
                                .font(AppStyle.Font.defaultFont)
                                .foregroundColor(AppStyle.Color.white)
                                .padding(.leading, 8)
                        }
                    }
                    .padding()
                }
                .listRowBackground(AppStyle.Color.backgroundColor)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationTitle("Muscle Categories")
        .onAppear {
            viewModel.updateExerciseCounts()
        }
    }
}
