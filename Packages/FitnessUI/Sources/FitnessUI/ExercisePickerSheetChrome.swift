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

// MARK: - Keyboard Visible Environment Key

private struct KeyboardVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var keyboardIsVisible: Bool {
        get { self[KeyboardVisibleKey.self] }
        set { self[KeyboardVisibleKey.self] = newValue }
    }
}

// MARK: - Shared Sheet Modifier

public struct ExercisePickerSheetModifier: ViewModifier {
    let isContentVisible: Bool

    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    public init(isContentVisible: Bool) {
        self.isContentVisible = isContentVisible
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.titleTop)
            .padding(.bottom, 28)
            #if canImport(UIKit)
            .environment(\.keyboardIsVisible, keyboard.isVisible)
            #endif
            .background(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.sheet, style: .continuous)
                    .fill(AppStyle.Color.sheetBackground)
            )
            .frame(maxWidth: .infinity)
            #if canImport(UIKit)
            .padding(.bottom, keyboard.height > 0 ? keyboard.height - 28 : 0)
            #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .opacity(isContentVisible ? 1 : 0)
            .allowsHitTesting(isContentVisible)
    }
}

public extension View {
    func exercisePickerSheet(isContentVisible: Bool) -> some View {
        modifier(ExercisePickerSheetModifier(isContentVisible: isContentVisible))
    }
}

// MARK: - Shared Action Buttons

public struct ExercisePickerActionButtons: View {
    let saveDisabled: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    public init(saveDisabled: Bool, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.saveDisabled = saveDisabled
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        HStack {
            Spacer()

            Text("Cancel")
                .foregroundColor(.white)
                .font(AppStyle.Font.pickerAction)
                .padding(5)
                .frame(width: 120)
                .cornerRadius(AppStyle.CornerRadius.editPickerViewButton)
                .onTapGesture { onCancel() }
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()

            Button("Save") { onSave() }
                .foregroundColor(.white)
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
