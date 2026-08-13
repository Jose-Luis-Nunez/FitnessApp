import SwiftUI
import FitnessCore
import FitnessUI
import FitnessWorkouts
import Factory

/// Collapsible "Friends" card embedded in `ProfileView`.
///
/// When expanded it shows:
/// - A user row (own name + avatar) tappable to trigger export
/// - A horizontal row of friend tiles + a "+" tile
/// - A comparison area (left = my metrics, right = selected friend's metrics)
public struct FriendsSection: View {
    @State private var viewModel = FriendsViewModel()
    @Environment(\.appColorTheme) private var appColorTheme

    private var profileColors: ProfileColorTheme { appColorTheme.profile }
    private let friendImportCoordinator = Container.shared.friendImportCoordinator()

    public init() {}

    public var body: some View {
        ProfileCardContainer {
            VStack(spacing: AppStyle.Padding.card) {
                headerRow

                if viewModel.isExpanded {
                    Group {
                        userRow
                        friendTileRow
                        comparisonArea
                    }
                }
            }
        }
        .friendImportFlow(
            viewModel: viewModel,
            coordinator: friendImportCoordinator
        )
        .sheet(isPresented: $viewModel.showingExportPicker) {
            ExportWorkoutPickerSheet(
                isPresented: $viewModel.showingExportPicker,
                workouts: viewModel.allWorkouts,
                onSelect: { viewModel.requestShare(for: $0) },
                exerciseCount: { viewModel.exerciseCount(for: $0) },
                workoutToShare: $viewModel.workoutToShare
            )
        }
        .alert("Export failed", isPresented: Binding(
            get: { viewModel.exportErrorMessage != nil },
            set: { if !$0 { viewModel.exportErrorMessage = nil } }
        )) {
            Button("OK") { viewModel.exportErrorMessage = nil }
        } message: {
            Text(viewModel.exportErrorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        Button {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                viewModel.toggleExpanded()
            }
        } label: {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                ProfileCardHeading("Friends")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(profileColors.accent)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("id_friends_section_header")
    }

    private var userRow: some View {
        Button {
            viewModel.requestExport()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(profileColors.innerBackground)
                        .frame(width: AppStyle.Layout.friendUserAvatarSize, height: AppStyle.Layout.friendUserAvatarSize)
                        .overlay {
                            Circle()
                                .stroke(
                                    profileColors.innerStroke,
                                    lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                                )
                        }
                    Text(viewModel.myNickname.prefix(1).uppercased())
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(profileColors.accent)
                }

                Text(viewModel.myNickname)
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(profileColors.title)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(profileColors.accent)
            }
            .padding(.vertical, AppStyle.Padding.cardVertical)
            .padding(.horizontal, AppStyle.Padding.card)
            .profileReadOnlyTileSurface(cornerRadius: AppStyle.CornerRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("id_friends_user_row")
    }

    private var friendTileRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.friends) { friend in
                    friendTile(friend)
                }
                addFriendTile
            }
        }
    }

    private func friendTile(_ friend: Friend) -> some View {
        Button {
            viewModel.selectFriend(friend)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(viewModel.selectedFriendId == friend.id
                              ? profileColors.accentFill
                              : profileColors.innerBackground)
                        .frame(width: AppStyle.Layout.friendAvatarSize, height: AppStyle.Layout.friendAvatarSize)
                        .overlay {
                            Circle()
                                .stroke(
                                    profileColors.innerStroke,
                                    lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                                )
                        }
                    Text(friend.name.prefix(1).uppercased())
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(
                            viewModel.selectedFriendId == friend.id
                            ? profileColors.onAccent
                            : profileColors.accent
                        )
                }
                Text(friend.name)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.title)
                    .lineLimit(1)
                    .frame(maxWidth: AppStyle.Layout.friendTileNameMaxWidth)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteFriend(friend)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("id_friends_tile_\(friend.id)")
    }

    private var addFriendTile: some View {
        Button {
            viewModel.requestFriendImport()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(
                            profileColors.innerStroke,
                            lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                        )
                        .frame(width: AppStyle.Layout.friendAvatarSize, height: AppStyle.Layout.friendAvatarSize)
                    Image(systemName: "plus")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(profileColors.accent)
                }
                Text("Add")
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("id_friends_add_button")
    }

    @ViewBuilder
    private var comparisonArea: some View {
        if let comparison = viewModel.comparison, let friend = viewModel.selectedFriend {
            FriendComparisonView(
                comparison: comparison,
                myName: viewModel.myNickname,
                friendName: friend.name
            )
        } else if viewModel.selectedFriendId != nil, let error = viewModel.comparisonError {
            Text(error)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(AppStyle.Color.error)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        } else if !viewModel.friends.isEmpty {
            Text("Select a friend")
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }

}
