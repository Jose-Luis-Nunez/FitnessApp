import SwiftUI

private struct IDS {
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()
    @State private var selectedGroup: MuscleCategoryGroup?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Text("Kategorien")
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                    .frame(height: 30)
                ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
                    NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                        CategoryTileView(group: group, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitle("")
        .onAppear {
            viewModel.updateExerciseCounts()
        }
    }
}

private struct CategoryTileView: View {
    let group: MuscleCategoryGroup
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel

    var body: some View {
        let exerciseCount = viewModel.getExerciseCount(for: group) ?? (0, 0)
        let total = exerciseCount.total
        let active = exerciseCount.active
        let isCompleted = active == 0 && total > 0
        let progress = total > 0 ? Double(total - active) / Double(total) : 0.0

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(group.displayName)
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                Text("\(active) von \(total) Übungen")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(SwiftUI.Color(hex: "#8a8580"))
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)

            Spacer()

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 18) {
                    CustomChip(text: isCompleted ? "Completed" : "Active", isCompleted: isCompleted)
                        .accessibilityIdentifier(IDS.label(for: group))
                    if total >= 0 {
                        ProgressView(value: progress)
                            .tint(AppStyle.Color.green)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            .frame(width: 100, height: 6, alignment: .trailing)
                            .padding(.horizontal, 0)
                    }
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.medium)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)
        }
        .frame(maxWidth: .infinity)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }

    private struct CustomChip: View {
        let text: String
        let isCompleted: Bool

        var body: some View {
            Text(text)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(width: 100, height: 28)
                .background(isCompleted ? AppStyle.Color.green : AppStyle.Color.exerciseCardBackground)
                .overlay(
                    isCompleted ? nil : RoundedRectangle(cornerRadius: 8)
                        .stroke(SwiftUI.Color(hex: "#8a8580"), lineWidth: 1)
                )
                .cornerRadius(8)
        }
    }
}
