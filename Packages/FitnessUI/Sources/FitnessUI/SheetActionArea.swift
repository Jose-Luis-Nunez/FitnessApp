import SwiftUI
import FitnessResources

/// Shared bottom action treatment for full-page and overlay sheets.
///
/// The secondary action keeps a fixed compact width while the primary action
/// receives the remaining space. A fading backdrop separates the actions from
/// scrolling content without introducing a hard horizontal color boundary.
public struct SheetActionArea: View {
    private let cancelLabel: LocalizedStringResource
    private let saveLabel: LocalizedStringResource
    private let isSaveEnabled: Bool
    private let backdropColor: Color
    private let cancelAccessibilityIdentifier: String
    private let saveAccessibilityIdentifier: String
    private let onCancel: () -> Void
    private let onSave: () -> Void

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    @Environment(\.appColorTheme) private var appColorTheme

    private static let homeMenuBarBottomOffset: CGFloat = -8
    private static let backdropFadeHeight: CGFloat = 28
    private static let backdropOpacity: Double = 0.94

    public init(
        cancelLabel: LocalizedStringResource = AppText.actionCancel,
        saveLabel: LocalizedStringResource,
        isSaveEnabled: Bool,
        backdropColor: Color,
        cancelAccessibilityIdentifier: String = "",
        saveAccessibilityIdentifier: String = "",
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.isSaveEnabled = isSaveEnabled
        self.backdropColor = backdropColor
        self.cancelAccessibilityIdentifier = cancelAccessibilityIdentifier
        self.saveAccessibilityIdentifier = saveAccessibilityIdentifier
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            backdrop

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
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var bottomPadding: CGFloat {
        max(0, safeAreaInsets.bottom + Self.homeMenuBarBottomOffset)
    }

    private var backdrop: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.clear,
                    backdropColor.opacity(Self.backdropOpacity),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.backdropFadeHeight)

            backdropColor
                .opacity(Self.backdropOpacity)
                .frame(height: AppStyle.Layout.sheetActionButtonHeight + bottomPadding)
        }
        .allowsHitTesting(false)
    }
}
