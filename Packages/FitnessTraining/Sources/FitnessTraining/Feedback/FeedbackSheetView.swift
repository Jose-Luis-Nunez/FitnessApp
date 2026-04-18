import SwiftUI
import FitnessCore
import FitnessUI

/// Post-exercise feedback **form** presented as a native iOS `.sheet` with
/// `.large` detent — the **same presentation pattern as `AnalyticsView`**.
/// The system-rendered grabber handle, status bar, and pull-to-dismiss
/// gesture all come for free; this view only renders the inner content.
///
/// Why a native `.sheet` and not `OverlaySheetContainer` or `.fullScreenCover`:
/// - The user already knows this presentation from `AnalyticsView` — same
///   grabber, same gesture, same look.
/// - `OverlaySheetContainer` is a custom bottom sheet meant for shorter
///   pickers; this form is far too tall for that layout.
/// - `.fullScreenCover` would not render the grabber the user expects.
///
/// Layout:
/// - Black background (set on the sheet via `.presentationBackground`).
/// - Title "How was the exercise?" centered at the top of the content area
///   (no NavigationStack, no toolbar — keep it lean and focussed).
/// - `ScrollView` with all sections (Pain, Symptoms, Energy, Note) — natural
///   scrolling, no height caps needed.
/// - Sticky `ExercisePickerActionButtons` (Cancel/Save) pinned to the safe-area
///   bottom — same component used by `AddAnalyticsEntryView` /
///   `ExercisePickerView` so the action-bar language stays consistent.
///
/// Dismiss flow:
/// - Save → `FeedbackViewModel.save()` → `onSaved` callback → parent closes.
/// - Cancel → immediate dismiss (no confirmation dialog — matches
///   `AddAnalyticsEntryView` and the rest of the app).
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                Text("How was the exercise?")
                    .font(AppStyle.Font.sheetTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, AppStyle.Padding.sectionSpacing)

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
                EnergyLevelSlider(selectedLevel: $viewModel.energyLevel)

                sectionTitle("Note")
                NoteField(text: $viewModel.note)
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.sectionSpacing)
            .padding(.bottom, AppStyle.Padding.sectionSpacing)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppStyle.Color.black)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ExercisePickerActionButtons(
                saveLabel: "Save",
                saveDisabled: !viewModel.isSaveEnabled,
                onCancel: { dismiss() },
                onSave: { save() }
            )
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, 24)
            .background(AppStyle.Color.black)
        }
        .preferredColorScheme(.dark)
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
