import SwiftUI
import FitnessResources

/// The Cancel/Save pair used at the bottom of the app's sheets: a fixed-width
/// borderless secondary action, and a filled primary action that takes the
/// remaining width up to a cap.
///
/// Split out of `SheetActionArea` so a sheet that already provides its own
/// bottom chrome — the picker sheets place their actions inside
/// `OverlaySheetContainer` — can use the same buttons without also inheriting
/// that component's backdrop fade and safe-area padding. The buttons are the
/// part that has to look the same everywhere; the chrome around them is the
/// host sheet's business.
public struct SheetActionButtons: View {
    private let cancelLabel: LocalizedStringResource
    private let saveLabel: LocalizedStringResource
    private let isSaveEnabled: Bool
    private let cancelAccessibilityIdentifier: String
    private let saveAccessibilityIdentifier: String
    private let onCancel: () -> Void
    private let onSave: () -> Void

    @Environment(\.appColorTheme) private var appColorTheme

    public init(
        cancelLabel: LocalizedStringResource = AppText.actionCancel,
        saveLabel: LocalizedStringResource,
        isSaveEnabled: Bool,
        cancelAccessibilityIdentifier: String = "",
        saveAccessibilityIdentifier: String = "",
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.isSaveEnabled = isSaveEnabled
        self.cancelAccessibilityIdentifier = cancelAccessibilityIdentifier
        self.saveAccessibilityIdentifier = saveAccessibilityIdentifier
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        HStack(spacing: AppStyle.Padding.card) {
            Button(cancelLabel, action: onCancel)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white)
                .frame(
                    width: AppStyle.Layout.sheetActionSecondaryButtonWidth,
                    height: AppStyle.Layout.sheetActionButtonHeight
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier(cancelAccessibilityIdentifier)

            Button(action: onSave) {
                Text(saveLabel)
                    .font(AppStyle.Font.bottomBarButtons)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: AppStyle.Layout.sheetActionButtonHeight,
                        maxHeight: AppStyle.Layout.sheetActionButtonHeight
                    )
                    .background(
                        isSaveEnabled
                            ? appColorTheme.accent.primary
                            : appColorTheme.accent.primary.opacity(0.15)
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: AppStyle.CornerRadius.editPickerViewButton,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: AppStyle.Layout.sheetActionPrimaryButtonMaxWidth)
            .disabled(!isSaveEnabled)
            .accessibilityIdentifier(saveAccessibilityIdentifier)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
