import SwiftUI
import FitnessCore
import FitnessUI
import FitnessResources

/// Two-column comparison area showing metrics for the user (left) and the
/// selected friend (right). Tapping a category row navigates to the drill-down.
struct FriendComparisonView: View {
    let comparison: FriendComparison
    let myName: String
    let friendName: String

    // Snapshot captured at tap-time so the sheet stays stable if comparison changes while open.
    @State private var detailComparison: FriendCategoryComparison?
    @State private var showingDetail = false
    @Environment(\.appColorTheme) private var appColorTheme

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

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
            Text(verbatim: myName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(AppText.analyticsCategory)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(verbatim: friendName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
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
                    Text(verbatim: "\(myCount)")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(profileColors.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(category.localizedName)
                            .font(AppStyle.Font.defaultFont)
                            .foregroundColor(profileColors.secondary)
                        if hasPairs {
                            Image(systemName: "chevron.right")
                                .font(AppStyle.Font.cardSmallLabel)
                                .foregroundColor(profileColors.accent.opacity(AppStyle.Opacity.secondaryLabel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    Text(verbatim: "\(friendCount)")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(profileColors.title)
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
                .background(profileColors.divider)
                .padding(.vertical, 4)

            comparisonRow(
                label: AppText.friendTrainingDaysMonth,
                myValue: "\(comparison.myMetrics.trainingDaysThisMonth)",
                friendValue: "\(comparison.friendMetrics.trainingDaysThisMonth)"
            )
            comparisonRow(
                label: AppText.friendTotalExercises,
                myValue: "\(comparison.myMetrics.totalExercises)",
                friendValue: "\(comparison.friendMetrics.totalExercises)"
            )
        }
    }

    private func comparisonRow(label: LocalizedStringResource, myValue: String, friendValue: String) -> some View {
        HStack {
            Text(verbatim: myValue)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(profileColors.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(verbatim: friendValue)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(profileColors.title)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }
}
