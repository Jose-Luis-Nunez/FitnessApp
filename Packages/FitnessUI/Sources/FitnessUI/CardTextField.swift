import SwiftUI

/// Single-line text input styled to match the wheel-picker cards: a muted label
/// over an editable field with a placeholder, on a dark rounded card with a
/// hairline border. Shared by the exercise name bar and the new-workout sheet.
public struct CardTextField: View {
    private let label: String
    private let placeholder: String
    @Binding private var text: String
    private var isFocused: FocusState<Bool>.Binding
    private let accessibilityIdentifier: String?

    /// Matches the wheel-card look (`ExerciseWheelPickerRow` columns).
    private let cornerRadius: CGFloat = 16

    public init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        accessibilityIdentifier: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isFocused = isFocused
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.placeholderText))
                }
                textField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var textField: some View {
        let input = TextField("", text: $text)
            .font(AppStyle.Font.sheetSectionLabel)
            .foregroundColor(AppStyle.Color.white)
            .tint(AppStyle.Color.white)
            .textFieldStyle(PlainTextFieldStyle())
            .focused(isFocused)
            .submitLabel(.done)
            .onSubmit { isFocused.wrappedValue = false }

        if let accessibilityIdentifier {
            input.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            input
        }
    }
}
