import SwiftUI

public struct WorkoutFormSheet<Content: View>: View {
    let title: String
    let isSaveDisabled: Bool
    let onSave: () -> Void
    /// Whether tapping the Save button auto-dismisses the sheet. Default `true`
    /// preserves the original behavior for create / rename flows. Set to
    /// `false` for flows that may fail (e.g. import) and need to keep the
    /// sheet open while the caller surfaces an error — the caller then drives
    /// dismissal manually by setting `isPresented` to `false` on success.
    /// V2 cleanup: replace with an async `() async -> Bool` onSave returning
    /// the dismiss decision.
    let dismissOnSave: Bool
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    public init(title: String, isSaveDisabled: Bool, onSave: @escaping () -> Void, isPresented: Binding<Bool>, dismissOnSave: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isSaveDisabled = isSaveDisabled
        self.onSave = onSave
        self.dismissOnSave = dismissOnSave
        self._isPresented = isPresented
        self.content = content
    }

    public var body: some View {
        ZStack {
            AppStyle.Color.backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                dragIndicator
                headerView
                content()
                Spacer()
                saveButtonView
            }
        }
    }

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(AppStyle.Color.gray.opacity(0.4))
            .frame(width: AppStyle.Layout.grabberWidth, height: AppStyle.Layout.grabberHeight)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }

    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(AppStyle.Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Image(systemName: "xmark")
                        .font(AppStyle.Font.tileLabel)
                        .foregroundColor(AppStyle.Color.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 16)

            Spacer()

            Text(title)
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)

            Spacer()

            Button(action: {}) {
                Image(systemName: "xmark")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.large)
            }
            .opacity(0)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
        .background(AppStyle.Color.backgroundColor)
    }

    private var saveButtonView: some View {
        VStack(spacing: 16) {
            Button(action: {
                onSave()
                if dismissOnSave {
                    isPresented = false
                }
            }) {
                Text("Save")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isSaveDisabled ? AppStyle.Color.gray : AppStyle.Color.green)
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)
            }
            .disabled(isSaveDisabled)
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.bottom, safeAreaInset + 16)
        }
    }

    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private var safeAreaInset: CGFloat { safeAreaInsets.bottom }
}
