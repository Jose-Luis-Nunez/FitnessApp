import SwiftUI
import FitnessCore
import FitnessUI

public struct FeedbackSheetView: View {
    @Bindable var viewModel: FeedbackViewModel
    @Binding var isPresented: Bool
    let onSaved: (ExerciseFeedback) -> Void

    @State private var isProcessingSaveCancel = false

    public init(
        viewModel: FeedbackViewModel,
        isPresented: Binding<Bool>,
        onSaved: @escaping (ExerciseFeedback) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onSaved = onSaved
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            backgroundColor: AppStyle.Color.black,
            onCancel: { dismiss() },
            actions: {
                ExercisePickerActionButtons(
                    saveLabel: "Save",
                    saveDisabled: !viewModel.isSaveEnabled,
                    onCancel: { dismiss() },
                    onSave: { save() }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                    Text("How was the exercise?")
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                            sectionTitle("Pain (optional)")
                            PainRegionGrid(
                                category: viewModel.painCategory,
                                selectedRegions: viewModel.painRegions,
                                onToggle: { viewModel.togglePainRegion($0) }
                            )

                            sectionTitle("Symptoms")
                            SymptomChipsView(
                                selected: viewModel.symptoms,
                                onToggle: { viewModel.toggleSymptom($0) }
                            )

                            sectionTitle("Energy level")
                            EnergyLevelSlider(
                                selectedLevel: $viewModel.energyLevel
                            )

                            sectionTitle("Note")
                            NoteField(text: $viewModel.note)
                        }
                        .padding(.bottom, AppStyle.Layout.sheetContentBottomPad)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(AppStyle.Font.sheetSectionLabel)
            .foregroundColor(AppStyle.Color.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dismiss() {
        guard !isProcessingSaveCancel else { return }
        isProcessingSaveCancel = true
        isPresented = false
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isProcessingSaveCancel = false
        }
    }

    private func save() {
        guard !isProcessingSaveCancel else { return }
        isProcessingSaveCancel = true
        if let persisted = viewModel.save() {
            onSaved(persisted)
        }
        isPresented = false
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isProcessingSaveCancel = false
        }
    }
}

private struct NoteField: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                .fill(AppStyle.Color.sheetInputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                )

            if text.isEmpty {
                Text("Optional: e.g. right shoulder unstable from set 3")
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(minHeight: 60, maxHeight: 80)
    }
}
