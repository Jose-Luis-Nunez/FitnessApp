import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

/// Post-exercise feedback **form** presented by `FeedbackSheetComponent` with
/// **two progressive rest heights** (the training sheet's measured height and
/// a large state). The states are managed by the presenting component.
/// The visible grabber matches the training sheet; the presenting component
/// owns its drag-to-expand, drag-to-collapse, and drag-to-dismiss behavior.
///
/// Layout:
/// - The presenting component supplies the same dark gradient, border, size,
///   and corner shape as the training sheet. Both the sticky header and the
///   action area scrim the content underneath with the ambient surface's own
///   base colour and fade out at their inner edge, so neither reads as a band
///   across the sheet.
/// - Title "Exercise Feedback" centered at the top of the content area
///   (no NavigationStack, no toolbar — keep it lean and focussed).
/// - `ScrollView` with progressive-disclosure sections:
///   1. **Physical Symptoms** (always visible)
///   2. **Pain** (only when `.pain` symptom selected)
///   3. **Energy level** (only when at least one symptom is selected)
///   4. **Notes** (only when at least one symptom is selected)
///   The form starts minimal and reveals follow-up questions only after the
///   user signals that something is worth elaborating on.
/// - Sticky Cancel/Save action area pinned to the safe-area bottom, matching
///   `WorkoutAnalyticsEntryView` in button sizing, spacing, and backdrop fade.
///   The left button is labelled **Cancel**. Closing the sheet does **not**
///   discard unsaved changes — they remain in the
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
/// Action bar visibility: the Cancel/Save bar is hidden while the Notes
/// keyboard is open. The blue "Done" submit key on the keyboard is the
/// single, unambiguous "I'm finished typing" affordance — once the user
/// confirms, the keyboard dismisses and the Cancel/Save bar reappears for
/// the actual sheet decision. This avoids the visual stack of "blue Done
/// + green Save" competing for the user's attention while typing.
///
/// Dismiss flow:
/// - **Save** → `FeedbackViewModel.save()` upserts the per-session record in
///   storage (icon flips to `done`) → `onSaved` callback → parent closes.
/// - **Cancel / X / Swipe-down** → immediate dismiss, no commit. Draft remains
///   in memory; re-opening the sheet rehydrates it. Discard happens only on
///   exercise switch / Beenden / Cancel / Reset (handled by the coordinator).
public struct FeedbackSheetView: View {
    @Bindable var viewModel: FeedbackViewModel
    @Binding var isPresented: Bool
    let onSaved: (ExerciseFeedback) -> Void
    let painRegionImageProvider: (BodyRegion) -> Image
    @State private var isProcessingSaveCancel = false
    @FocusState private var isNotesFocused: Bool

    public init(
        viewModel: FeedbackViewModel,
        isPresented: Binding<Bool>,
        onSaved: @escaping (ExerciseFeedback) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onSaved = onSaved
        self.painRegionImageProvider = { Image($0.iconAssetName) }
    }

    init(
        viewModel: FeedbackViewModel,
        isPresented: Binding<Bool>,
        onSaved: @escaping (ExerciseFeedback) -> Void = { _ in },
        painRegionImageProvider: @escaping (BodyRegion) -> Image
    ) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onSaved = onSaved
        self.painRegionImageProvider = painRegionImageProvider
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                sectionTitle(
                    AppText.feedbackPhysicalSymptoms,
                    alignment: .center
                )
                SymptomChipsView(
                    selected: viewModel.symptoms,
                    onToggle: { viewModel.toggleSymptom($0) }
                )

                if viewModel.symptoms.contains(.pain) {
                    sectionTitle(AppText.feedbackPain)
                    PainRegionGrid(
                        category: viewModel.painCategory,
                        selectedRegions: viewModel.painRegions,
                        onToggle: { viewModel.togglePainRegion($0) },
                        imageProvider: painRegionImageProvider
                    )
                }

                if !viewModel.symptoms.isEmpty {
                    sectionTitle(AppText.feedbackEnergyLevel)
                    EnergyLevelSlider(selectedLevel: $viewModel.energyLevel)

                    sectionTitle(AppText.feedbackNotes)
                    NoteField(text: $viewModel.note, isFocused: $isNotesFocused)
                }
            }
            .padding(.horizontal, Self.contentHorizontalPadding)
            .padding(.top, Self.contentTopPadding)
            .padding(.bottom, AppStyle.Padding.sectionSpacing)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(viewModel.symptoms.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .safeAreaInset(edge: .top, spacing: 0) {
            feedbackSheetHeader
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isNotesFocused {
                feedbackActionArea
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isNotesFocused)
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.energyLevel) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.painRegions) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.symptoms) { _, _ in viewModel.autosaveDraft() }
        .onChange(of: viewModel.note) { _, _ in viewModel.autosaveDraft() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TrainingIDs.feedbackSheet)
    }

    /// Left and right content margin for every element in this sheet, taken
    /// from the training sheet so the two surfaces — which share size, shape,
    /// and background — also share their edge inset.
    private static let contentHorizontalPadding =
        AppStyle.Layout.trainingSheetContentHorizontalPadding

    /// The sheet title and the first section heading are both centred and read
    /// as one block, so the gap between them is tighter than
    /// `sectionSpacing` — which is calibrated for separating unrelated
    /// sections. The height this frees goes to the symptom tiles.
    private static let headerTitleBottomPadding: CGFloat = 10
    private static let contentTopPadding: CGFloat = 6

    /// Leading by default. The first section is centred instead: it sits
    /// directly under the centred sheet title with no content above it, so a
    /// left-aligned label there reads as a stray line rather than as a heading.
    @ViewBuilder
    private func sectionTitle(
        _ text: LocalizedStringResource,
        alignment: Alignment = .leading
    ) -> some View {
        Text(text)
            .font(AppStyle.Font.sheetSectionLabel)
            .foregroundColor(AppStyle.Color.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var feedbackSheetGrabber: some View {
        SheetGrabber()
            .accessibilityElement()
            .accessibilityLabel(AppText.feedbackCancel)
            .accessibilityHint(AppText.feedbackCancelHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { dismiss() }
            .accessibilityIdentifier(TrainingIDs.feedbackSheetGrabber)
    }

    private var feedbackSheetHeader: some View {
        VStack(spacing: 0) {
            feedbackSheetGrabber

            Text(AppText.feedbackTitle)
                .font(AppStyle.Font.sheetTitle)
                .foregroundColor(AppStyle.Color.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppStyle.Padding.sectionSpacing)
                .padding(.bottom, Self.headerTitleBottomPadding)
        }
        .background(headerScrim)
    }

    /// The sticky header must hide content scrolling underneath it without
    /// reading as a band across the sheet. A flat fill did exactly that: it was
    /// a different colour than the ambient surface behind it and met the scroll
    /// area with a hard edge. This scrim uses the ambient base colour instead
    /// and fades out over its last quarter, so the boundary dissolves and the
    /// surface's colour washes stay visible through it.
    private var headerScrim: some View {
        LinearGradient(
            stops: [
                .init(color: AppStyle.Color.ambientBase.opacity(0.92), location: 0.0),
                .init(color: AppStyle.Color.ambientBase.opacity(0.92), location: 0.75),
                .init(color: AppStyle.Color.ambientBase.opacity(0.0), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var feedbackActionArea: some View {
        SheetActionArea(
            saveLabel: AppText.actionSave,
            isSaveEnabled: viewModel.isSaveEnabled,
            // Matches the sheet's `AmbientScreenBackground` base rather than
            // the old card gradient's bottom stop, which showed as a lighter
            // band across the action area.
            backdropColor: AppStyle.Color.ambientBase,
            horizontalPadding: Self.contentHorizontalPadding,
            cancelAccessibilityIdentifier: TrainingIDs.feedbackCancelButton,
            saveAccessibilityIdentifier: TrainingIDs.feedbackSaveButton,
            onCancel: dismiss,
            onSave: save
        )
        .zIndex(2)
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
                Text(AppText.feedbackNoteExample)
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
