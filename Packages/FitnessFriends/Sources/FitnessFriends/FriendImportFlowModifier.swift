import SwiftUI
import FitnessResources

/// Owns the full-screen host for the edge-to-edge Add Friend overlay and
/// app-level `.fitnessfriend` delivery.
/// Manual file selection lives inside `AddFriendSheet`; externally opened
/// files arrive through `FriendImportCoordinator` and use the same form.
struct FriendImportFlowModifier: ViewModifier {
    @Bindable var viewModel: FriendsViewModel
    let importCoordinator: FriendImportCoordinator

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showingAddFriend) {
                AddFriendSheet(
                    isPresented: $viewModel.showingAddFriend,
                    initialJSON: viewModel.pendingFriendJSON,
                    fileName: viewModel.pendingFriendFileName,
                    importCoordinator: importCoordinator,
                    onAdded: { viewModel.friendAdded() }
                )
            }
            .onAppear {
                receivePendingImport(importCoordinator.pendingImportJSON)
            }
            .onChange(of: importCoordinator.pendingImportJSON) { _, json in
                receivePendingImport(json)
            }
            .onChange(of: viewModel.showingAddFriend) { _, isPresented in
                if !isPresented {
                    viewModel.friendImportDidDismiss()
                }
            }
            .alert(AppText.workoutImportFailedTitle, isPresented: $viewModel.importFailed) {
                Button(AppText.actionOk) { viewModel.importFailed = false }
            } message: {
                Text(AppText.friendFileUnreadable)
            }
    }

    private func receivePendingImport(_ json: String?) {
        guard let json else { return }

        let fileName = importCoordinator.pendingImportFileName
        importCoordinator.clearPending()
        viewModel.receiveFriendImport(json: json, fileName: fileName)
    }
}

extension View {
    func friendImportFlow(
        viewModel: FriendsViewModel,
        coordinator: FriendImportCoordinator
    ) -> some View {
        modifier(
            FriendImportFlowModifier(
                viewModel: viewModel,
                importCoordinator: coordinator
            )
        )
    }
}
