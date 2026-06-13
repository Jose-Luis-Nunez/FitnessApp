import SwiftUI
import FitnessCore
import FitnessUI

/// Two-column comparison area showing metrics for the user (left) and the
/// selected friend (right). Tapping a category row navigates to the drill-down.
struct FriendComparisonView: View {
    let comparison: FriendComparison
    let myName: String
    let friendName: String

    // Snapshot captured at tap-time so the sheet stays stable if comparison changes while open.
    @State private var detailComparison: FriendCategoryComparison?
    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 8) {
            columnHeaders
            categoryRows
            summaryRows
        }
        .sheet(isPresented: $showingDetail) {
            if let catComp = detailComparison {
                NavigationStack {
                    FriendCategoryDetailView(
                        categoryComparison: catComp,
                        myName: myName,
                        friendName: friendName
                    )
                }
            }
        }
    }

    private var columnHeaders: some View {
        HStack {
            Text(myName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(AppStyle.Color.greenLight)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Category")
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(AppStyle.Color.greenLight)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(friendName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(AppStyle.Color.greenLight)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }

    private var categoryRows: some View {
        ForEach(MuscleCategoryGroup.allCases) { category in
            let myCount = comparison.myMetrics.categoryCounts.first { $0.category == category }?.count ?? 0
            let friendCount = comparison.friendMetrics.categoryCounts.first { $0.category == category }?.count ?? 0
            let catComparison = comparison.categoryComparisons.first { $0.category == category }
            let hasPairs = !(catComparison?.matchedPairs.isEmpty ?? true)

            Button {
                if hasPairs {
                    detailComparison = catComparison
                    showingDetail = true
                }
            } label: {
                HStack {
                    Text("\(myCount)")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(category.displayName)
                            .font(AppStyle.Font.defaultFont)
                            .foregroundColor(AppStyle.Color.greenLight)
                        if hasPairs {
                            Image(systemName: "chevron.right")
                                .font(AppStyle.Font.cardSmallLabel)
                                .foregroundColor(AppStyle.Color.greenLight.opacity(AppStyle.Opacity.secondaryLabel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    Text("\(friendCount)")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("id_friends_comparison_\(category.rawValue)")
        }
    }

    private var summaryRows: some View {
        VStack(spacing: 8) {
            Divider()
                .background(AppStyle.Color.greenLight.opacity(0.2))
                .padding(.vertical, 4)

            comparisonRow(
                label: "Training days / month",
                myValue: "\(comparison.myMetrics.trainingDaysThisMonth)",
                friendValue: "\(comparison.friendMetrics.trainingDaysThisMonth)"
            )
            comparisonRow(
                label: "Total exercises",
                myValue: "\(comparison.myMetrics.totalExercises)",
                friendValue: "\(comparison.friendMetrics.totalExercises)"
            )
        }
    }

    private func comparisonRow(label: String, myValue: String, friendValue: String) -> some View {
        HStack {
            Text(myValue)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.greenLight)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(friendValue)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}
