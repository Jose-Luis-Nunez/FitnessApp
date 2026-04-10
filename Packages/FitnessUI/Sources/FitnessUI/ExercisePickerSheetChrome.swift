import SwiftUI

// MARK: - Shared Sheet Modifier

public struct ExercisePickerSheetModifier: ViewModifier {
    let isContentVisible: Bool

    public init(isContentVisible: Bool) {
        self.isContentVisible = isContentVisible
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppStyle.Color.sheetBackground)
            )
            .frame(maxWidth: .infinity)
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
