import SwiftUI
import FitnessCore
import FitnessUI
import FitnessResources

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
            title: AppText.workoutImport,
            isSaveDisabled: viewModel.isImportDisabled,
            onSave: { viewModel.importTapped() },
            isPresented: $isPresented,
            dismissOnSave: false
        ) {
            VStack(spacing: 20) {
                instructionSection
                clipboardButton
                editorSection
                if let error = viewModel.error {
                    errorPill(error: error)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, AppStyle.Padding.horizontal)
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppText.workoutPasteJson)
                .font(.headline)
                .foregroundColor(textColor)
            Text(AppText.workoutPasteInstructions)
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
                Text(AppText.workoutPasteClipboard)
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

    private func errorPill(error: WorkoutImportFailure) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error.localizedResource)
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

private extension WorkoutImportFailure {
    var localizedResource: LocalizedStringResource {
        switch self {
        case .invalidJSON: AppText.errorInvalidWorkoutJson
        case .newerVersion: AppText.errorNewerWorkoutVersion
        case .incompleteData: AppText.errorIncompleteWorkout
        case .savingFailed: AppText.errorSavingFailed
        }
    }
}
