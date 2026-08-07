import SwiftUI

/// Shared bottom action treatment for full-page and overlay sheets.
///
/// The secondary action keeps a fixed compact width while the primary action
/// receives the remaining space. A fading backdrop separates the actions from
/// scrolling content without introducing a hard horizontal color boundary.
public struct SheetActionArea: View {
    private let cancelLabel: String
    private let saveLabel: String
    private let isSaveEnabled: Bool
    private let backdropColor: Color
    private let cancelAccessibilityIdentifier: String
    private let saveAccessibilityIdentifier: String
    private let onCancel: () -> Void
    private let onSave: () -> Void

    @Environment(\.safeAreaInsets) private var safeAreaInsets

    private static let cancelButtonWidth: CGFloat = 120
    private static let saveButtonMaxWidth: CGFloat = 225
    private static let actionButtonHeight: CGFloat = 52
    private static let homeMenuBarBottomOffset: CGFloat = -8
    private static let backdropFadeHeight: CGFloat = 28
    private static let backdropOpacity: Double = 0.94

    public init(
        cancelLabel: String = "Cancel",
        saveLabel: String,
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
                        width: Self.cancelButtonWidth,
                        height: Self.actionButtonHeight
                    )
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(cancelAccessibilityIdentifier)

                Button(action: onSave) {
                    Text(saveLabel)
                        .font(AppStyle.Font.bottomBarButtons)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: Self.actionButtonHeight,
                            maxHeight: Self.actionButtonHeight
                        )
                        .background(
                            isSaveEnabled
                                ? AppStyle.Color.green
                                : AppStyle.Color.green.opacity(0.15)
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: AppStyle.CornerRadius.editPickerViewButton,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: Self.saveButtonMaxWidth)
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
                .frame(height: Self.actionButtonHeight + bottomPadding)
        }
        .allowsHitTesting(false)
    }
}
