import SwiftUI
#if canImport(UIKit)
import UIKit
import Combine
#endif

// MARK: - Keyboard Height Observer

#if canImport(UIKit)
@MainActor
@Observable
public final class KeyboardObserver {
    public var height: CGFloat = 0
    public var isVisible: Bool { height > 0 }

    private var cancellables: Set<AnyCancellable> = []

    public init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] h in
                withAnimation(AppStyle.Animation.keyboardSpring) { self?.height = h }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation(AppStyle.Animation.keyboardSpring) { self?.height = 0 }
            }
            .store(in: &cancellables)
    }
}
#endif

// MARK: - Shared Sheet Modifier

public struct ExercisePickerSheetModifier: ViewModifier {
    let isContentVisible: Bool
    let backgroundColor: Color
    let borderColor: Color?

    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    public init(
        isContentVisible: Bool,
        backgroundColor: Color = AppStyle.Color.sheetBackground,
        borderColor: Color? = nil
    ) {
        self.isContentVisible = isContentVisible
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AppStyle.CornerRadius.sheet,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppStyle.CornerRadius.sheet,
            style: .continuous
        )
    }

    public func body(content: Content) -> some View {
        content
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .background(
                sheetShape
                    .fill(backgroundColor)
                    .overlay(
                        sheetShape.strokeBorder(borderColor ?? .clear, lineWidth: 1)
                    )
                    .ignoresSafeArea(.container, edges: .bottom)
            )
            #if canImport(UIKit)
            .padding(.bottom, keyboard.height > 0 ? keyboard.height - 28 : 0)
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(isContentVisible ? 1 : 0)
            .allowsHitTesting(isContentVisible)
    }
}

public extension View {
    func exercisePickerSheet(
        isContentVisible: Bool,
        backgroundColor: Color = AppStyle.Color.sheetBackground,
        borderColor: Color? = nil
    ) -> some View {
        modifier(ExercisePickerSheetModifier(
            isContentVisible: isContentVisible,
            backgroundColor: backgroundColor,
            borderColor: borderColor
        ))
    }
}

// MARK: - Sheet Action Bar

public struct SheetActionBar<Actions: View>: View {
    @ViewBuilder let actions: () -> Actions

    public init(@ViewBuilder actions: @escaping () -> Actions) {
        self.actions = actions
    }

    public var body: some View {
        actions()
            .padding(.top, AppStyle.Padding.actionBarTop)
    }
}

// MARK: - Overlay Sheet Container

public struct OverlaySheetContainer<Content: View, Actions: View, Overlay: View>: View {
    @Binding var isPresented: Bool
    let allowBackdropDismiss: Bool
    let backgroundColor: Color
    let borderColor: Color?
    let expandsToTop: Bool
    let onCancel: () -> Void
    @ViewBuilder let overlay: () -> Overlay
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content

    @State private var isContentVisible: Bool = false

    public init(
        isPresented: Binding<Bool>,
        allowBackdropDismiss: Bool = true,
        backgroundColor: Color = AppStyle.Color.sheetBackground,
        borderColor: Color? = nil,
        expandsToTop: Bool = false,
        onCancel: @escaping () -> Void,
        @ViewBuilder overlay: @escaping () -> Overlay,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _isPresented = isPresented
        self.allowBackdropDismiss = allowBackdropDismiss
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.expandsToTop = expandsToTop
        self.onCancel = onCancel
        self.overlay = overlay
        self.actions = actions
        self.content = content
    }

    private func dismiss() {
        onCancel()
        isPresented = false
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                .ignoresSafeArea()
                .onTapGesture {
                    if allowBackdropDismiss { dismiss() }
                }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                // Full-height sheets scroll their content between the fixed
                // grabber and action bar, so the content's top stays put
                // regardless of how tall a given step is. Bottom sheets keep
                // their natural, content-sized height.
                if expandsToTop {
                    ScrollView {
                        content()
                    }
                    .scrollIndicators(.hidden)
                } else {
                    content()
                }

                SheetActionBar { actions() }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.titleTop)
            .frame(maxHeight: expandsToTop ? .infinity : nil, alignment: .top)
            .exercisePickerSheet(isContentVisible: isContentVisible, backgroundColor: backgroundColor, borderColor: borderColor)
            .gesture(
                DragGesture().onEnded { value in
                    if allowBackdropDismiss && value.translation.height > 80 { dismiss() }
                }
            )

            overlay()
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { isContentVisible = true }
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue { isContentVisible = false }
        }
    }
}

// Convenience: no overlay, no actions (content-only)
public extension OverlaySheetContainer where Overlay == EmptyView, Actions == EmptyView {
    init(
        isPresented: Binding<Bool>,
        allowBackdropDismiss: Bool = true,
        backgroundColor: Color = AppStyle.Color.sheetBackground,
        borderColor: Color? = nil,
        expandsToTop: Bool = false,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            allowBackdropDismiss: allowBackdropDismiss,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            expandsToTop: expandsToTop,
            onCancel: onCancel,
            overlay: { EmptyView() },
            actions: { EmptyView() },
            content: content
        )
    }
}

// Convenience: no overlay, with actions
public extension OverlaySheetContainer where Overlay == EmptyView {
    init(
        isPresented: Binding<Bool>,
        allowBackdropDismiss: Bool = true,
        backgroundColor: Color = AppStyle.Color.sheetBackground,
        borderColor: Color? = nil,
        expandsToTop: Bool = false,
        onCancel: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            allowBackdropDismiss: allowBackdropDismiss,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            expandsToTop: expandsToTop,
            onCancel: onCancel,
            overlay: { EmptyView() },
            actions: actions,
            content: content
        )
    }
}

// MARK: - Shared Action Buttons

public struct ExercisePickerActionButtons: View {
    let cancelLabel: String
    let saveLabel: String
    let cancelColor: Color
    let saveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    public init(
        cancelLabel: String = "Cancel",
        saveLabel: String = "Save",
        cancelColor: Color = AppStyle.Color.white,
        saveDisabled: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.cancelColor = cancelColor
        self.saveDisabled = saveDisabled
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        HStack {
            Spacer()

            Button(cancelLabel) { onCancel() }
                .foregroundColor(cancelColor)
                .font(AppStyle.Font.pickerAction)
                .padding(5)
                .frame(width: 120)
                .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Button(saveLabel) { onSave() }
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.pickerAction)
                .padding(5)
                .frame(width: 140, height: 40)
                .background(saveDisabled ? AppStyle.Color.green.opacity(0.15) : AppStyle.Color.green)
                .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                .disabled(saveDisabled)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, 5)
    }
}
