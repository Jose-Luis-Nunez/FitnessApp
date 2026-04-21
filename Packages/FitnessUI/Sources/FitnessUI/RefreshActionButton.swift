import SwiftUI

/// Solid-green pill button used to manually refresh remote data (Tram, BMI, …).
/// Mirrors the Save button in `ExercisePickerActionButtons` so the action-bar
/// language stays consistent across the app.
public struct RefreshActionButton: View {
    private let title: String
    private let isLoading: Bool
    private let action: () -> Void

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
                        .tint(AppStyle.Color.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(AppStyle.Font.profileSmallIcon)
                }
                Text(title)
                    .font(AppStyle.Font.pickerAction)
                    .fixedSize()
            }
            .foregroundColor(AppStyle.Color.white)
            // 140×40 mirrors the Save button in `ExercisePickerActionButtons` —
            // intentionally kept literal so both stay byte-identical when one is updated.
            .frame(width: 140, height: 40)
            .background(isLoading ? AppStyle.Color.green.opacity(0.6) : AppStyle.Color.green)
            .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
