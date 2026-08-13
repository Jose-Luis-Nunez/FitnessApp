import SwiftUI
import FitnessCore
import FitnessUI

struct ImportWorkoutView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    @Binding var isPresented: Bool
    @State private var viewModel: ImportWorkoutViewModel

    init(
        isPresented: Binding<Bool>,
        initialText: String? = nil,
        onImported: @escaping (Workout) -> Void
    ) {
        self._isPresented = isPresented
        self._viewModel = State(initialValue: ImportWorkoutViewModel(
            initialText: initialText,
            onImported: onImported,
            onDismiss: { isPresented.wrappedValue = false }
        ))
    }

    private let textColor = AppStyle.Color.white

    var body: some View {
        WorkoutFormSheet(
            title: "Import Workout",
            isSaveDisabled: viewModel.isImportDisabled,
            onSave: { viewModel.importTapped() },
            isPresented: $isPresented,
            dismissOnSave: false
        ) {
            VStack(spacing: 20) {
                instructionSection
                clipboardButton
                editorSection
                if let message = viewModel.errorMessage {
                    errorPill(message: message)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste JSON")
                .font(.headline)
                .foregroundColor(textColor)
            Text("Paste the exported workout JSON below. It will be created as a new workout — existing workouts will not be overwritten.")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clipboardButton: some View {
        Button(action: { viewModel.pasteFromClipboard() }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                Text("Paste from clipboard")
                    .font(AppStyle.Font.defaultFont)
            }
            .foregroundColor(appColorTheme.accent.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(appColorTheme.accent.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorSection: some View {
        TextEditor(text: $viewModel.pastedText)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(textColor)
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(minHeight: 240)
            .background(AppStyle.Color.backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppStyle.Color.gray, lineWidth: 1)
            )
    }

    private func errorPill(message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.red.opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}
