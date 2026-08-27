import SwiftUI
import FitnessResources
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

// MARK: - Sheet Surface

/// How a bottom sheet paints itself.
///
/// One value rather than a colour plus an "ignore the colour" flag: the two
/// could previously be set contradictorily, and the colour was silently dead
/// whenever the ambient surface was requested.
public enum SheetSurface: Equatable, Sendable {
    /// Flat fill, with an optional hairline border.
    case flat(Color, border: Color? = nil)
    /// The backdrop shared with the training and feedback sheets. For sheets
    /// presented as their siblings; it carries its own border.
    case ambient

    public static var `default`: SheetSurface { .flat(AppStyle.Color.sheetBackground) }
}

// MARK: - Shared Sheet Modifier

public struct ExercisePickerSheetModifier: ViewModifier {
    let isContentVisible: Bool
    let surface: SheetSurface
    /// Exact visible height for the sheet, excluding the bottom safe area.
    /// `nil` keeps the default content-sized height. Set it when the sheet has
    /// to occupy the same frame as another sheet in the same flow — a
    /// content-sized sheet cannot match one whose height is measured elsewhere.
    let fixedHeight: CGFloat?
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    public init(
        isContentVisible: Bool,
        surface: SheetSurface = .default,
        fixedHeight: CGFloat? = nil
    ) {
        self.isContentVisible = isContentVisible
        self.surface = surface
        self.fixedHeight = fixedHeight
    }

    /// The sheet's box extends under the bottom safe area, so the requested
    /// visible height has to be grown by that inset for the *top* edge to land
    /// where the measured sheet's top edge is.
    private var resolvedHeight: CGFloat? {
        fixedHeight.map { $0 + safeAreaInsets.bottom }
    }


    @ViewBuilder
    private var surfaceBody: some View {
        switch surface {
        case .ambient:
            AmbientSheetSurface()
        case let .flat(color, border):
            AmbientSheetSurface.shape
                .fill(color)
                .overlay(
                    AmbientSheetSurface.shape
                        .strokeBorder(border ?? .clear, lineWidth: 1)
                )
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    public func body(content: Content) -> some View {
        content
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
            .frame(height: resolvedHeight, alignment: .top)
            .background(surfaceBody)
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
        surface: SheetSurface = .default,
        fixedHeight: CGFloat? = nil
    ) -> some View {
        modifier(ExercisePickerSheetModifier(
            isContentVisible: isContentVisible,
            surface: surface,
            fixedHeight: fixedHeight
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
    let surface: SheetSurface
    let expandsToTop: Bool
    /// Forwarded to `exercisePickerSheet`. When set, the action bar is pushed to
    /// the sheet's bottom edge instead of trailing the content, so the freed
    /// space opens up between content and actions rather than below them.
    let fixedHeight: CGFloat?
    /// `true` (default): the container draws its own backdrop and fades its
    /// content in on appear.
    ///
    /// `false`: the caller owns the backdrop and the appear/disappear
    /// animation. Required when the sheet has to slide in, because a slide has
    /// to animate the sheet *without* dragging the backdrop along with it —
    /// which is only expressible where the two are separate views, i.e. at the
    /// call site. The container's own fade would also run on top of it.
    let ownsPresentation: Bool
    let onCancel: () -> Void
    @ViewBuilder let overlay: () -> Overlay
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content

    @State private var isContentVisible: Bool = false

    public init(
        isPresented: Binding<Bool>,
        allowBackdropDismiss: Bool = true,
        surface: SheetSurface = .default,
        expandsToTop: Bool = false,
        fixedHeight: CGFloat? = nil,
        ownsPresentation: Bool = true,
        onCancel: @escaping () -> Void,
        @ViewBuilder overlay: @escaping () -> Overlay,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _isPresented = isPresented
        self.allowBackdropDismiss = allowBackdropDismiss
        self.surface = surface
        self.expandsToTop = expandsToTop
        self.fixedHeight = fixedHeight
        self.ownsPresentation = ownsPresentation
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
            if ownsPresentation {
                Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if allowBackdropDismiss { dismiss() }
                    }
            }

            VStack(spacing: 0) {
                SheetGrabber()

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

                if fixedHeight != nil {
                    Spacer(minLength: 0)
                }

                SheetActionBar { actions() }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            // No top padding: `SheetGrabber` carries its own inset, and adding
            // another one here pushed the handle 8pt below where the training
            // sheet's sits. The content keeps its distance to the handle.
            // A fixed-height sheet has to let its stack fill that height,
            // otherwise the stack stays content-sized and the action-bar
            // spacer has nothing to expand into.
            .frame(
                maxHeight: (expandsToTop || fixedHeight != nil) ? .infinity : nil,
                alignment: .top
            )
            .exercisePickerSheet(
                isContentVisible: isContentVisible,
                surface: surface,
                fixedHeight: fixedHeight
            )
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
            guard ownsPresentation else {
                isContentVisible = true
                return
            }
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
        surface: SheetSurface = .default,
        expandsToTop: Bool = false,
        fixedHeight: CGFloat? = nil,
        ownsPresentation: Bool = true,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            allowBackdropDismiss: allowBackdropDismiss,
            surface: surface,
            expandsToTop: expandsToTop,
            fixedHeight: fixedHeight,
            ownsPresentation: ownsPresentation,
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
        surface: SheetSurface = .default,
        expandsToTop: Bool = false,
        fixedHeight: CGFloat? = nil,
        ownsPresentation: Bool = true,
        onCancel: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            allowBackdropDismiss: allowBackdropDismiss,
            surface: surface,
            expandsToTop: expandsToTop,
            fixedHeight: fixedHeight,
            ownsPresentation: ownsPresentation,
            onCancel: onCancel,
            overlay: { EmptyView() },
            actions: actions,
            content: content
        )
    }
}

// MARK: - Shared Action Buttons

public struct ExercisePickerActionButtons: View {
    @Environment(\.appColorTheme) private var appColorTheme
    let cancelLabel: LocalizedStringResource
    let saveLabel: LocalizedStringResource
    let cancelColor: Color
    let saveColorOverride: Color?
    let saveForegroundColor: Color
    let saveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let saveAccessibilityIdentifier: String?

    public init(
        cancelLabel: LocalizedStringResource = AppText.actionCancel,
        saveLabel: LocalizedStringResource = AppText.actionSave,
        cancelColor: Color = AppStyle.Color.white,
        saveColor: Color? = nil,
        saveForegroundColor: Color = AppStyle.Color.white,
        saveDisabled: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveAccessibilityIdentifier: String? = nil
    ) {
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.cancelColor = cancelColor
        saveColorOverride = saveColor
        self.saveForegroundColor = saveForegroundColor
        self.saveDisabled = saveDisabled
        self.onCancel = onCancel
        self.onSave = onSave
        self.saveAccessibilityIdentifier = saveAccessibilityIdentifier
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

            saveButton

            Spacer()
        }
        .padding(.horizontal, 5)
    }

    @ViewBuilder
    private var saveButton: some View {
        let saveColor = saveColorOverride ?? appColorTheme.accent.primary
        let button = Button(saveLabel) { onSave() }
            .foregroundColor(saveForegroundColor)
            .font(AppStyle.Font.pickerAction)
            .padding(5)
            .frame(width: 140, height: 40)
            .background(saveDisabled ? saveColor.opacity(AppStyle.Opacity.disabledElement) : saveColor)
            .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
            .disabled(saveDisabled)
            .frame(maxWidth: .infinity, alignment: .center)

        if let saveAccessibilityIdentifier {
            button.accessibilityIdentifier(saveAccessibilityIdentifier)
        } else {
            button
        }
    }
}
