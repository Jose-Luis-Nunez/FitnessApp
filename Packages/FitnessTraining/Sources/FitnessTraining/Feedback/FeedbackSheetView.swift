import SwiftUI
import FitnessCore
import FitnessUI

/// Post-exercise feedback **form** presented as a native iOS `.sheet` with
/// **two progressive detents** (a content-fitted `.height(...)` and `.large`)
/// — the **same presentation pattern as `AnalyticsView`** for the grabber /
/// system look. The detents are managed by the presenting
/// `FeedbackSheetComponent`; this view exposes the natural height of its
/// initial content (Title + Symptom-Tiles) via `onInitialContentHeightChange`
/// so the small detent always exactly fits its visible content.
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
/// - App background (`AppStyle.Color.backgroundColor`, `#0A090E`) set on the
///   sheet via `.presentationBackground`. Matches `MuscleCategoryView` and
///   `AnalyticsView` so the sheet reads as a continuation of the app shell
///   rather than a foreign black surface.
/// - Title "Exercise Feedback" centered at the top of the content area
///   (no NavigationStack, no toolbar — keep it lean and focussed).
/// - `ScrollView` with progressive-disclosure sections:
///   1. **Physical Symptoms** (always visible)
///   2. **Pain** (only when `.pain` symptom selected)
///   3. **Energy level** (only when at least one symptom is selected)
///   4. **Notes** (only when at least one symptom is selected)
///   The form starts minimal and reveals follow-up questions only after the
///   user signals that something is worth elaborating on.
/// - Sticky `ExercisePickerActionButtons` (Hide/Save) pinned to the safe-area
///   bottom — same component used by `AddAnalyticsEntryView` /
///   `ExercisePickerView` so the action-bar language stays consistent.
///   The left button is labelled **Hide** (not Cancel) because closing the
///   sheet does **not** discard unsaved changes — they remain in the
///   in-memory draft store and re-appear on next open. Save is the only
///   button that commits to storage.
///
/// Auto-save (draft): every relevant field change calls
/// `viewModel.autosaveDraft()` so the in-memory draft store always reflects
/// the latest form state. Drafts live in memory only and are discarded on
/// exercise switch / Beenden / Cancel / Reset — see
/// `ExerciseFeedbackDraftStore`. They are **never** persisted automatically;
/// only an explicit Save tap moves the entry into storage.
///
/// Notes keyboard: the notes field is a single-line `TextField` with
/// `.submitLabel(.done)` + `.onSubmit` so Return shows the blue check
/// confirm key on the iOS keyboard and dismisses the keyboard cleanly —
/// the **same pattern as `ExerciseNamePickerView` ("Edit Title")**, which
/// the user already knows.
///
/// Action bar visibility: the Hide/Save bar is hidden while the Notes
/// keyboard is open. The blue "Done" submit key on the keyboard is the
/// single, unambiguous "I'm finished typing" affordance — once the user
/// confirms, the keyboard dismisses and the Hide/Save bar reappears for
/// the actual sheet decision. This avoids the visual stack of "blue Done
/// + green Save" competing for the user's attention while typing.
///
/// Dismiss flow:
/// - **Save** → `FeedbackViewModel.save()` upserts the per-session record in
///   storage (icon flips to `done`) → `onSaved` callback → parent closes.
/// - **Hide / X / Swipe-down** → immediate dismiss, no commit. Draft remains
///   in memory; re-opening the sheet rehydrates it. Discard happens only on
///   exercise switch / Beenden / Cancel / Reset (handled by the coordinator).
public struct FeedbackSheetView: View {
    @Bindable var viewModel: FeedbackViewModel
    @Binding var isPresented: Bool
    let onSaved: (ExerciseFeedback) -> Void
    /// Reports the natural pixel height of the **initial** sheet content
    /// (Title + Physical-Symptoms tiles + Hide/Save action bar) so the
    /// presenting component can size the small/initial `.presentationDetents`
    /// to exactly fit. Called every time the layout settles; the component
    /// can debounce / take the latest value.
    let onInitialContentHeightChange: (CGFloat) -> Void

    @State private var isProcessingSaveCancel = false
    @FocusState private var isNotesFocused: Bool

    fileprivate static let contentCoordinateSpace = "FeedbackSheetContent"

    public init(
        viewModel: FeedbackViewModel,
        isPresented: Binding<Bool>,
        onSaved: @escaping (ExerciseFeedback) -> Void = { _ in },
        onInitialContentHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onSaved = onSaved
        self.onInitialContentHeightChange = onInitialContentHeightChange
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                Text("Exercise Feedback")
                    .font(AppStyle.Font.sheetTitle)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, AppStyle.Padding.sectionSpacing)

                sectionTitle("Physical Symptoms")
                SymptomChipsView(
                    selected: viewModel.symptoms,
                    onToggle: { viewModel.toggleSymptom($0) }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: InitialContentHeightKey.self,
                            value: proxy.frame(in: .named(Self.contentCoordinateSpace)).maxY
                        )
                    }
                )

                if viewModel.symptoms.contains(.pain) {
                    sectionTitle("Pain")
                    PainRegionGrid(
                        category: viewModel.painCategory,
                        selectedRegions: viewModel.painRegions,
                        onToggle: { viewModel.togglePainRegion($0) }
                    )
                }

                if !viewModel.symptoms.isEmpty {
                    sectionTitle("Energy level")
                    EnergyLevelSlider(selectedLevel: $viewModel.energyLevel)

                    sectionTitle("Notes")
                    NoteField(text: $viewModel.note, isFocused: $isNotesFocused)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.sectionSpacing)
            .padding(.bottom, AppStyle.Padding.sectionSpacing)
        }
        .coordinateSpace(name: Self.contentCoordinateSpace)
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppStyle.Color.backgroundColor)
        .onPreferenceChange(InitialContentHeightKey.self) { initialBlockMaxY in
            // initialBlockMaxY is the bottom edge of the SymptomChipsView measured
            // from the top of the ScrollView content (i.e. the natural height of
            // Title + Section label + 2x2 tiles incl. top padding). Add bottom
            // section spacing so the small detent has visual breathing room
            // before the sticky action bar; the action-bar height itself is
            // added by the presenting component (it owns the safe-area inset).
            onInitialContentHeightChange(initialBlockMaxY + AppStyle.Padding.sectionSpacing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isNotesFocused {
                ExercisePickerActionButtons(
                    cancelLabel: "Hide",
                    saveLabel: "Save",
                    saveDisabled: !viewModel.isSaveEnabled,
                    onCancel: { dismiss() },
                    onSave: { save() }
                )
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, 24)
                .background(AppStyle.Color.backgroundColor)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNotesFocused)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.energyLevel) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.painRegions) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.symptoms) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.note) { _, _ in viewModel.autosaveDraft() }
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

private struct InitialContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct NoteField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                .fill(AppStyle.Color.sheetInputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.tile, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                )

            if text.isEmpty {
                Text("e.g. shoulder hurt during last set")
                    .font(AppStyle.Font.tileLabel)
                    .foregroundColor(AppStyle.Color.white.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            // Single-line text field with the iOS blue-checkmark "Done"
            // submit key — same pattern as `ExerciseNamePickerView` ("Edit
            // Title") which the user already knows. The wrapper reserves
            // a multi-line visual height so existing notes still wrap and
            // read well, but Return immediately confirms and dismisses
            // the keyboard.
            TextField("", text: $text)
                .focused($isFocused)
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileLabel)
                .submitLabel(.done)
                .onSubmit { isFocused = false }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .frame(minHeight: 64, alignment: .topLeading)
    }
}
