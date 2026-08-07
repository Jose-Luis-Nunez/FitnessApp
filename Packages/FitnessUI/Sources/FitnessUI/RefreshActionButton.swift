import SwiftUI

/// Profile-accent pill button used to manually refresh remote data (Tram, BMI, …).
public struct RefreshActionButton: View {
    private let title: String
    private let isLoading: Bool
    private let action: () -> Void
    @Environment(\.profileColorTheme) private var profileColors

    public init(
        title: String = "Refresh",
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                if isLoading {
                    ProgressView()
                        .tint(profileColors.onAccent)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(AppStyle.Font.profileSmallIcon)
                }
                Text(title)
                    .font(AppStyle.Font.pickerAction)
                    .fixedSize()
            }
            .foregroundColor(profileColors.onAccent)
            // 140×40 mirrors the Save button in `ExercisePickerActionButtons` —
            // intentionally kept literal so both stay byte-identical when one is updated.
            .frame(width: 140, height: 40)
            .background(profileColors.accentFill)
            .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
        }
        .buttonStyle(ProfileAccentButtonStyle())
        .disabled(isLoading)
    }
}

/// Keeps the semantic disabled state without applying the system's additional
/// disabled alpha, which would reduce contrast on the dark accent button.
private struct ProfileAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
