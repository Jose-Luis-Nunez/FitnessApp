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
    private let horizontalPadding: CGFloat
    private let cancelAccessibilityIdentifier: String
    private let saveAccessibilityIdentifier: String
    private let onCancel: () -> Void
    private let onSave: () -> Void

    @Environment(\.safeAreaInsets) private var safeAreaInsets

    private static let homeMenuBarBottomOffset: CGFloat = -8
    private static let backdropFadeHeight: CGFloat = 28
    private static let backdropOpacity: Double = 0.94

    public init(
        cancelLabel: LocalizedStringResource = AppText.actionCancel,
        saveLabel: LocalizedStringResource,
        isSaveEnabled: Bool,
        backdropColor: Color,
        /// Content margin for the button row. Defaults to the standard sheet
        /// margin; pass the host sheet's own value when it differs, so the
        /// actions line up with the content they belong to.
        horizontalPadding: CGFloat = AppStyle.Padding.horizontal,
        cancelAccessibilityIdentifier: String = "",
        saveAccessibilityIdentifier: String = "",
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.isSaveEnabled = isSaveEnabled
        self.backdropColor = backdropColor
        self.horizontalPadding = horizontalPadding
        self.cancelAccessibilityIdentifier = cancelAccessibilityIdentifier
        self.saveAccessibilityIdentifier = saveAccessibilityIdentifier
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            backdrop

            SheetActionButtons(
                cancelLabel: cancelLabel,
                saveLabel: saveLabel,
                isSaveEnabled: isSaveEnabled,
                cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
                saveAccessibilityIdentifier: saveAccessibilityIdentifier,
                onCancel: onCancel,
                onSave: onSave
            )
            .padding(.horizontal, horizontalPadding)
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
