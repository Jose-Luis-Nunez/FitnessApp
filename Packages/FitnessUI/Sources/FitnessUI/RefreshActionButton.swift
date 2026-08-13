import SwiftUI

/// Semantic wrapper for a primary Profile refresh action.
public struct RefreshActionButton: View {
    private let title: String
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        title: String = "Refresh",
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        ProfileActionRow(
            primaryLabel: title,
            primarySystemImage: "arrow.clockwise",
            isPrimaryEnabled: isEnabled,
            isPrimaryLoading: isLoading,
            onPrimary: action
        )
        .frame(width: AppStyle.Layout.profileActionPrimaryButtonMaxWidth)
    }
}
