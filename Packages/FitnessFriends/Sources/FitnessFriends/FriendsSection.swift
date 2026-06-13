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
    private let friendImportCoordinator = Container.shared.friendImportCoordinator()

    public init() {}

    public var body: some View {
        profileCard {
            VStack(spacing: AppStyle.Padding.card) {
                headerRow

                if viewModel.isExpanded {
                    userRow
                    friendTileRow
                    comparisonArea
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddFriend) {
            AddFriendSheet(
                isPresented: $viewModel.showingAddFriend,
                initialJSON: viewModel.pendingFriendJSON,
                fileName: viewModel.pendingFriendFileName,
                onAdded: {
                    viewModel.pendingFriendJSON = nil
                    viewModel.pendingFriendFileName = nil
                    viewModel.friendAdded()
                }
            )
        }
        .onAppear {
            if let json = friendImportCoordinator.pendingImportJSON, !json.isEmpty {
                viewModel.pendingFriendJSON = json
                viewModel.pendingFriendFileName = friendImportCoordinator.pendingImportFileName
                friendImportCoordinator.clearPending()
                viewModel.showingAddFriend = true
            }
        }
        .onChange(of: friendImportCoordinator.pendingImportJSON) { _, json in
            guard let json, !json.isEmpty else { return }
            viewModel.pendingFriendJSON = json
            viewModel.pendingFriendFileName = friendImportCoordinator.pendingImportFileName
            friendImportCoordinator.clearPending()
            viewModel.showingAddFriend = true
        }
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
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleExpanded()
            }
        } label: {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                Text("Friends")
                    .font(AppStyle.Font.sectionHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .fixedSize()
                Spacer()
                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(AppStyle.Color.greenLight)
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
                        .fill(AppStyle.Color.greenDark)
                        .frame(width: AppStyle.Layout.friendUserAvatarSize, height: AppStyle.Layout.friendUserAvatarSize)
                    Text(viewModel.myNickname.prefix(1).uppercased())
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }

                Text(viewModel.myNickname)
                    .font(AppStyle.Font.tileValue)
                    .foregroundColor(AppStyle.Color.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(AppStyle.Color.green)
            }
            .padding(.vertical, AppStyle.Padding.cardVertical)
            .padding(.horizontal, AppStyle.Padding.card)
            .background(AppStyle.Color.greenDark.opacity(AppStyle.Opacity.fadedOverlay))
            .cornerRadius(AppStyle.CornerRadius.card)
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
                              ? AppStyle.Color.green
                              : AppStyle.Color.greenDark)
                        .frame(width: AppStyle.Layout.friendAvatarSize, height: AppStyle.Layout.friendAvatarSize)
                    Text(friend.name.prefix(1).uppercased())
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.white)
                }
                Text(friend.name)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(AppStyle.Color.white)
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
            viewModel.showingAddFriend = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(AppStyle.Color.greenLight.opacity(AppStyle.Opacity.fadedOverlay), lineWidth: 1.5)
                        .frame(width: AppStyle.Layout.friendAvatarSize, height: AppStyle.Layout.friendAvatarSize)
                    Image(systemName: "plus")
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(AppStyle.Color.greenLight)
                }
                Text("Add")
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(AppStyle.Color.greenLight)
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
                .foregroundColor(AppStyle.Color.greenLight)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
    }

    // MARK: - Card container (mirrors ProfileCard from ProfileView)

    @ViewBuilder
    private func profileCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(AppStyle.Padding.card)
        .frame(
            maxWidth: .infinity,
            minHeight: AppStyle.Layout.profileCardCollapsedMinHeight,
            alignment: .leading
        )
        .background(AppStyle.Color.profileCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }
}
