import SwiftUI

/// Shared action composition for profile cards and profile-owned sheets.
///
/// The optional secondary action stays visually quiet while the primary
/// action uses the environment-injected profile accent. Loading and disabled
/// states live here so Save and Refresh controls cannot drift across Profile,
/// Friends, and transit content.
public struct ProfileActionRow: View {
    private let secondaryLabel: String?
    private let primaryLabel: String
    private let primarySystemImage: String?
    private let isPrimaryEnabled: Bool
    private let isPrimaryLoading: Bool
    private let secondaryAccessibilityIdentifier: String
    private let primaryAccessibilityIdentifier: String
    private let onSecondary: () -> Void
    private let onPrimary: () -> Void

    @Environment(\.profileColorTheme) private var profileColors

    public init(
        secondaryLabel: String? = nil,
        primaryLabel: String,
        primarySystemImage: String? = nil,
        isPrimaryEnabled: Bool = true,
        isPrimaryLoading: Bool = false,
        secondaryAccessibilityIdentifier: String = "",
        primaryAccessibilityIdentifier: String = "",
        onSecondary: @escaping () -> Void = {},
        onPrimary: @escaping () -> Void
    ) {
        self.secondaryLabel = secondaryLabel
        self.primaryLabel = primaryLabel
        self.primarySystemImage = primarySystemImage
        self.isPrimaryEnabled = isPrimaryEnabled
        self.isPrimaryLoading = isPrimaryLoading
        self.secondaryAccessibilityIdentifier = secondaryAccessibilityIdentifier
        self.primaryAccessibilityIdentifier = primaryAccessibilityIdentifier
        self.onSecondary = onSecondary
        self.onPrimary = onPrimary
    }

    @ViewBuilder
    public var body: some View {
        if let secondaryLabel {
            HStack(spacing: AppStyle.Padding.card) {
                Button(secondaryLabel, action: onSecondary)
                    .font(AppStyle.Font.bottomBarButtons)
                    .foregroundColor(profileColors.title)
                    .frame(
                        width: AppStyle.Layout.profileActionSecondaryButtonWidth,
                        height: AppStyle.Layout.minimumTapTargetSize
                    )
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(secondaryAccessibilityIdentifier)

                primaryButton
                    .frame(maxWidth: AppStyle.Layout.profileActionPrimaryButtonMaxWidth)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            primaryButton
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                if isPrimaryLoading {
                    ProgressView()
                        .tint(profileColors.onAccent)
                } else if let primarySystemImage {
                    Image(systemName: primarySystemImage)
                        .font(AppStyle.Font.profileSmallIcon)
                }

                Text(primaryLabel)
                    .font(AppStyle.Font.bottomBarButtons)
                    .fixedSize()
            }
            .foregroundColor(profileColors.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: AppStyle.Layout.minimumTapTargetSize)
            .background(
                profileColors.accentFill.opacity(
                    isPrimaryEnabled && !isPrimaryLoading
                        ? 1
                        : AppStyle.Opacity.disabledElement
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppStyle.CornerRadius.editPickerViewButton,
                    style: .continuous
                )
            )
        }
        .buttonStyle(ProfilePrimaryActionButtonStyle())
        .disabled(!isPrimaryEnabled || isPrimaryLoading)
        .accessibilityIdentifier(primaryAccessibilityIdentifier)
    }
}

private struct ProfilePrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
