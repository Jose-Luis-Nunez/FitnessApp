import SwiftUI

public struct WorkoutFormSheet<Content: View>: View {
    let title: String
    let isSaveDisabled: Bool
    let onSave: () -> Void
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    public init(title: String, isSaveDisabled: Bool, onSave: @escaping () -> Void, isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.isSaveDisabled = isSaveDisabled
        self.onSave = onSave
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
                isPresented = false
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
