import SwiftUI
import FitnessCore
import FitnessUI
import FitnessResources

/// Drill-down view showing only exercises whose names appear in both the user's
/// and the friend's workout for the selected category.
public struct FriendCategoryDetailView: View {
    public let categoryComparison: FriendCategoryComparison
    public let myName: String
    public let friendName: String
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    public init(
        categoryComparison: FriendCategoryComparison,
        myName: String,
        friendName: String
    ) {
        self.categoryComparison = categoryComparison
        self.myName = myName
        self.friendName = friendName
    }

    public var body: some View {
        ZStack {
            AppStyle.Color.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headerRow

                    if categoryComparison.matchedPairs.isEmpty {
                        emptyState
                    } else {
                        ForEach(categoryComparison.matchedPairs) { pair in
                            exercisePairRow(pair)
                        }
                    }

                    if categoryComparison.friendExclusiveCount > 0 {
                        exclusiveFooter
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, AppStyle.Padding.titleTop)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(Text(categoryComparison.category.localizedName))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerRow: some View {
        HStack {
            Text(verbatim: myName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(AppText.exerciseSingular)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(verbatim: friendName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .profileCardSurface()
    }

    private func exercisePairRow(_ pair: ExercisePair) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: WeightFormatter.displayWeight(pair.myWeight, locale: locale))
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(profileColors.title)
                Text(AppText.exerciseRepetitionsCount(count: pair.myReps))
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: pair.name)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(profileColors.title)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: WeightFormatter.displayWeight(pair.friendWeight, locale: locale))
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(profileColors.title)
                Text(AppText.exerciseRepetitionsCount(count: pair.friendReps))
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .profileCardSurface()
        .accessibilityIdentifier("id_friends_detail_pair_\(pair.name)")
    }

    private var emptyState: some View {
        Text(AppText.friendNoSharedExercises)
            .font(AppStyle.Font.profileCardTitle)
            .foregroundColor(profileColors.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 32)
    }

    private var exclusiveFooter: some View {
        Text(AppText.friendExclusiveCount(count: categoryComparison.friendExclusiveCount, name: friendName))
            .font(AppStyle.Font.profileCardTitle)
            .foregroundColor(profileColors.secondary.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }
}
