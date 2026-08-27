import SwiftUI

/// The drag handle at the top of a bottom sheet.
///
/// Extracted because the training sheet, the feedback sheet, and the picker
/// sheets each drew their own capsule, and the picker sheets had drifted to a
/// hardcoded 44pt width while the others used the 36pt token. The handle is the
/// one element every sheet shares, so it must not be redrawn per sheet.
///
/// Carries only the visual and its hit area; gestures, accessibility, and
/// whatever "pull down" means are the host sheet's business and stay at the
/// call site.
public struct SheetGrabber: View {
    public init() {}

    public var body: some View {
        Capsule()
            .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
            .frame(
                width: AppStyle.Layout.grabberWidth,
                height: AppStyle.Layout.grabberHeight
            )
            .padding(.top, AppStyle.Padding.sheetGrabberTop)
            .padding(.bottom, AppStyle.Padding.sheetGrabberBottom)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }
}
