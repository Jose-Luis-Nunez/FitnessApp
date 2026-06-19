import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FitnessCore
import FitnessResources
import FitnessUI

/// The two steps of the new-exercise / full-edit flow.
/// `.details` collects name, icon and the set/reps/weight wheels;
/// `.machine` collects the seat ("machine") settings and commits the exercise.
private enum ExercisePickerStep {
    case details
    case machine
}

public struct ExercisePickerView: View {
    @Bindable public var formViewModel: ExerciseFormViewModel

    @Binding public var isPresented: Bool
    public let onSave: () -> Void
    public let onCancel: () -> Void
    public let repsRange: ClosedRange<Int>
    public let weightOptions: [String]
    public let setsRange: ClosedRange<Int>
    public var viewModel: MuscleCategoryViewModel
    public let editingExercise: Exercise?

    @State private var step: ExercisePickerStep = .details
    @FocusState private var isNameFocused: Bool
    #if canImport(UIKit)
    @State private var keyboard = KeyboardObserver()
    #endif

    private var hideChrome: Bool {
        #if canImport(UIKit)
        keyboard.isVisible
        #else
        false
        #endif
    }

    public init(
        formViewModel: ExerciseFormViewModel,
        isPresented: Binding<Bool>,
        onSave: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        repsRange: ClosedRange<Int>,
        weightOptions: [String],
        setsRange: ClosedRange<Int>,
        viewModel: MuscleCategoryViewModel,
        editingExercise: Exercise?
    ) {
        self.formViewModel = formViewModel
        _isPresented = isPresented
        self.onSave = onSave
        self.onCancel = onCancel
        self.repsRange = repsRange
        self.weightOptions = weightOptions
        self.setsRange = setsRange
        self.viewModel = viewModel
        self.editingExercise = editingExercise
    }

    public var body: some View {
        OverlaySheetContainer(
            isPresented: $isPresented,
            backgroundColor: AppStyle.Color.backgroundColor,
            expandsToTop: true,
            onCancel: onCancel,
            actions: {
                if !hideChrome {
                    actionButtons
                }
            },
            content: {
                // Shared header — rendered once above both steps so the body
                // preview stays at exactly the same height when paging.
                ExerciseIconHeader(
                    formViewModel: formViewModel,
                    title: formViewModel.selectedCategory.displayName
                )

                switch step {
                case .details:
                    detailsStep
                case .machine:
                    machineStep
                }
            }
        )
        .onAppear {
            // New exercise: seat settings start hidden until the user enables
            // "Seat required" (handled in SeatSettingsEditor); seed sensible
            // set/reps/weight defaults. The decimal / bodyweight state is owned
            // by ExerciseDetailsEditor.
            if editingExercise == nil {
                formViewModel.noSeats = true
                formViewModel.sets = max(setsRange.lowerBound, min(setsRange.upperBound, 3))
                formViewModel.reps = max(repsRange.lowerBound, min(repsRange.upperBound, 12))
                if weightOptions.contains("20") || weightOptions.contains("20,0") || weightOptions.contains("20.0") {
                    formViewModel.weight = 20
                }
            }
        }
    }

    // MARK: - Action Bar

    /// Step 1 shows Cancel | Continue; step 2 shows Back | Save. Continue is
    /// gated on `isFormValid` (same rule the old single-step Save used); Save
    /// is always enabled because seat settings are optional.
    @ViewBuilder
    private var actionButtons: some View {
        switch step {
        case .details:
            ExercisePickerActionButtons(
                cancelLabel: L10n.cardCreationCancel,
                saveLabel: L10n.cardCreationContinue,
                cancelColor: AppStyle.Color.green,
                saveDisabled: !formViewModel.isFormValid,
                onCancel: {
                    onCancel()
                    isPresented = false
                },
                onSave: {
                    isNameFocused = false
                    // No withAnimation: animating the teardown of the wheel
                    // pickers (UIKit UIPickerView) across the step swap crashes
                    // in UIView trait-change processing (EXC_BAD_ACCESS).
                    step = .machine
                }
            )
        case .machine:
            ExercisePickerActionButtons(
                cancelLabel: L10n.cardCreationBack,
                saveLabel: L10n.cardCreationSave,
                cancelColor: AppStyle.Color.green,
                saveDisabled: !formViewModel.isFormValid,
                onCancel: {
                    // Back: return to the details step — does NOT dismiss.
                    // Plain assignment (no animation) for the same reason as
                    // the forward transition: avoids the wheel-picker teardown
                    // crash during trait-change processing.
                    step = .details
                },
                onSave: {
                    onSave()
                    isPresented = false
                }
            )
        }
    }

    // MARK: - Step 1: Details (name + wheels + weight-mode cards)

    @ViewBuilder
    private var detailsStep: some View {
        ExerciseNameBar(text: $formViewModel.name, isFocused: $isNameFocused)
            .padding(.bottom, 12)

        ExerciseDetailsEditor(
            formViewModel: formViewModel,
            repsRange: repsRange,
            weightOptions: weightOptions,
            setsRange: setsRange,
            editingExisting: editingExercise != nil
        )
    }

    // MARK: - Step 2: Seat / machine setup

    private var machineStep: some View {
        SeatSettingsEditor(formViewModel: formViewModel)
    }
}

/// One ordered seat position; `id` gives stable identity for drag reordering.
struct SeatEntry: Identifiable, Equatable {
    let id = UUID()
    var value: String
}

// MARK: - Reusable: Icon Header

/// Body-icon preview shared by the create flow's step 2 and the Edit-Seat
/// sheet: a swipeable paged gallery (when the category has more than one icon)
/// over a dotted ring, with a title below (category name, or "Edit Seat").
struct ExerciseIconHeader: View {
    @Bindable var formViewModel: ExerciseFormViewModel
    let title: String

    private let previewHeight: CGFloat = 260
    @State private var validIconOptions: [String] = []

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                MuscleIconBackdrop()
                gallery
            }
            .frame(height: previewHeight)

            Text(title)
                .font(AppStyle.Font.navigationHeadline)
                .foregroundColor(AppStyle.Color.white)
        }
        .padding(.bottom, 16)
        .onAppear {
            validIconOptions = formViewModel.selectedCategory.availableIcons.filter { name in
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                #if canImport(UIKit)
                return UIImage(named: name) != nil
                #else
                return true
                #endif
            }
            // Seed a concrete selection so the gallery binding is valid. New
            // exercises start empty → first (default) icon; edited ones keep
            // their icon.
            if !validIconOptions.contains(formViewModel.selectedIconName), let first = validIconOptions.first {
                formViewModel.selectedIconName = first
            }
        }
    }

    private var resolvedIconName: String {
        formViewModel.selectedIconName.isEmpty
        ? formViewModel.selectedCategory.defaultIconName
        : formViewModel.selectedIconName
    }

    @ViewBuilder
    private var gallery: some View {
        if validIconOptions.count > 1 {
            TabView(selection: $formViewModel.selectedIconName) {
                ForEach(validIconOptions, id: \.self) { icon in
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .tag(icon)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            #endif
            .frame(height: previewHeight)
        } else {
            Image(resolvedIconName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .clipped()
        }
    }
}

// MARK: - Reusable: Seat Settings Editor

/// "Seat required" toggle plus a dynamic, reorderable list of up to four seat
/// positions. Shared by the create flow's step 2 and the Edit-Seat sheet — the
/// values are loaded from (and written back to) `formViewModel.seat`, so an
/// exercise edited here shows exactly the positions it was saved with.
struct SeatSettingsEditor: View {
    @Bindable var formViewModel: ExerciseFormViewModel

    private let maxSeatSettings = SeatSettings.editableLimit
    @State private var seatValues: [SeatEntry] = []

    var body: some View {
        VStack(spacing: 20) {
            SeatRequiredBox(isOn: seatRequiredBinding)

            if !formViewModel.noSeats {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.seatSettingsTitle)
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(AppStyle.Color.white)
                        Text(L10n.seatSettingsSubtitle)
                            .font(AppStyle.Font.sheetCaption)
                            .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ReorderableSeatList(
                        entries: $seatValues,
                        onValueChange: updateSeat,
                        onRemove: { id in removeSeat(id: id) }
                    )

                    if seatValues.count < maxSeatSettings {
                        AddSeatSettingButton { addSeat() }
                    }
                }
            }
        }
        .onAppear { loadSeatValues() }
    }

    /// Toggle reflects "seat required" = the inverse of the model's `noSeats`.
    private var seatRequiredBinding: Binding<Bool> {
        Binding(
            get: { !formViewModel.noSeats },
            set: { required in
                formViewModel.noSeats = !required
                if required {
                    if seatValues.isEmpty {
                        seatValues = [SeatEntry(value: ""), SeatEntry(value: "")]
                    }
                } else {
                    seatValues = [SeatEntry(value: ""), SeatEntry(value: "")]
                    updateSeat()
                }
            }
        )
    }

    private func updateSeat() {
        formViewModel.seat = SeatSettings(positions: seatValues.map(\.value)).encoded ?? ""
    }

    private func loadSeatValues() {
        let positions = SeatSettings(encoded: formViewModel.seat).positions
        seatValues = positions.isEmpty
            ? [SeatEntry(value: ""), SeatEntry(value: "")]
            : positions.prefix(maxSeatSettings).map { SeatEntry(value: $0) }
    }

    private func addSeat() {
        guard seatValues.count < maxSeatSettings else { return }
        seatValues.append(SeatEntry(value: ""))
    }

    private func removeSeat(id: SeatEntry.ID) {
        seatValues.removeAll { $0.id == id }
        updateSeat()
    }
}

// MARK: - Reusable: Details Editor (wheels + weight modes)

/// The set/reps/weight wheels plus the "Additional options" toggles (bodyweight
/// exercise, 0.5 kg increments). Shared by the create flow's step 1 and the
/// standalone Edit-Exercise sheet. Owns the decimal / bodyweight UI state and
/// keeps it in sync with the model (bodyweight clears the weight and disables
/// decimals). The name input is *not* part of this editor — callers that want
/// it compose `ExerciseNameBar` above it.
struct ExerciseDetailsEditor: View {
    @Bindable var formViewModel: ExerciseFormViewModel
    let repsRange: ClosedRange<Int>
    let weightOptions: [String]
    let setsRange: ClosedRange<Int>
    /// True when editing an existing exercise: a stored weight of 0 then means
    /// "bodyweight" (start with the weight wheel hidden). A brand-new exercise
    /// never starts in bodyweight mode.
    let editingExisting: Bool

    @State private var showDecimal = false
    @State private var noWeight = false

    private var filteredWeightOptions: [String] {
        showDecimal ? weightOptions : weightOptions.filter { !$0.contains(",") && !$0.contains(".") }
    }

    var body: some View {
        VStack(spacing: AppStyle.Padding.sectionSpacing) {
            ExerciseWheelPickerRow(
                sets: $formViewModel.sets,
                reps: $formViewModel.reps,
                weight: Binding<String>(
                    get: { WeightFormatter.format(formViewModel.weight) },
                    set: { if let w = WeightFormatter.parse($0) { formViewModel.weight = w } }
                ),
                setsRange: setsRange,
                repsRange: repsRange,
                weightOptions: filteredWeightOptions,
                showWeight: !noWeight
            )

            ExerciseWeightModeCards(
                decimalOn: showDecimal,
                bodyweightOn: noWeight,
                onToggleDecimal: { showDecimal.toggle() },
                onToggleBodyweight: { noWeight.toggle() }
            )
        }
        .onAppear {
            let w = formViewModel.weight
            if w != floor(w) { showDecimal = true }
            if editingExisting, w == 0 { noWeight = true }
        }
        .onChange(of: noWeight) { _, isNoWeight in
            if isNoWeight {
                formViewModel.weight = 0
                // Decimal increments are meaningless without a weight.
                showDecimal = false
            }
        }
    }
}

// MARK: - Styled Name Bar

/// Name input styled to match the wheel picker cards (same dark fill, thin grey
/// border and corner radius): a muted label over a single-line editable name
/// with a placeholder. Sits under the body preview, above the wheels.
struct ExerciseNameBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    /// Matches the wheel-card look (`ExerciseWheelPickerRow` columns).
    private let cornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.exerciseNameLabel)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(L10n.exerciseNamePlaceholder)
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.placeholderText))
                }
                TextField("", text: $text)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(AppStyle.Color.white)
                    .tint(AppStyle.Color.white)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused(isFocused)
                    .submitLabel(.done)
                    .onSubmit { isFocused.wrappedValue = false }
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
}

// MARK: - Icon Backdrop

/// Decorative backdrop behind the body-icon preview: a faint concentric field
/// of dots inside a thin ring, fading toward the edges. Purely cosmetic.
private struct MuscleIconBackdrop: View {
    private let tint = AppStyle.Color.greenLight

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringDiameter = side * 0.92

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxRadius = ringDiameter / 2
                    let ringCount = 7
                    for ring in 1...ringCount {
                        let radius = maxRadius * CGFloat(ring) / CGFloat(ringCount)
                        let dotCount = max(8, ring * 7)
                        for i in 0..<dotCount {
                            let angle = (2 * Double.pi) * Double(i) / Double(dotCount)
                            let point = CGPoint(
                                x: center.x + radius * CGFloat(cos(angle)),
                                y: center.y + radius * CGFloat(sin(angle))
                            )
                            let dotSize: CGFloat = 1.6
                            let rect = CGRect(
                                x: point.x - dotSize / 2,
                                y: point.y - dotSize / 2,
                                width: dotSize,
                                height: dotSize
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(0.55)))
                        }
                    }
                }

                Circle()
                    .stroke(tint.opacity(0.5), lineWidth: 1)
                    .frame(width: ringDiameter, height: ringDiameter)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask(
                RadialGradient(
                    gradient: Gradient(colors: [Color.white, Color.white.opacity(0)]),
                    center: .center,
                    startRadius: side * 0.2,
                    endRadius: side * 0.62
                )
            )
        }
    }
}

// MARK: - Additional Options (weight modes)

/// "Additional options" list below the wheels: a section header, then two
/// toggle rows (Bodyweight exercise, Use 0.5 kg increments) separated by
/// hairline dividers — icon box + title/subtitle + switch, styled like the
/// design target with the app's green accent.
private struct ExerciseWeightModeCards: View {
    let decimalOn: Bool
    let bodyweightOn: Bool
    let onToggleDecimal: () -> Void
    let onToggleBodyweight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.additionalOptionsTitle)
                .font(AppStyle.Font.defaultFont)
                .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                .padding(.bottom, 10)

            divider

            ExerciseOptionRow(
                systemIcon: "figure.stand",
                title: L10n.weightModeBodyweightTitle,
                subtitle: L10n.weightModeBodyweightSubtitle,
                isOn: Binding(get: { bodyweightOn }, set: { _ in onToggleBodyweight() })
            )

            divider

            ExerciseOptionRow(
                systemIcon: "circle.lefthalf.filled",
                title: L10n.weightModeDecimalTitle,
                subtitle: L10n.weightModeDecimalSubtitle,
                isOn: Binding(get: { decimalOn }, set: { _ in onToggleDecimal() })
            )
            // Decimal increments only make sense with a weight.
            .opacity(bodyweightOn ? AppStyle.Opacity.disabledElement : 1)
            .disabled(bodyweightOn)

            divider
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.hairlineDivider))
            .frame(height: AppStyle.Layout.separatorWidth)
    }
}

private struct ExerciseOptionRow: View {
    let systemIcon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleBackground))
                    .frame(width: 40, height: 40)
                Image(systemName: systemIcon)
                    .font(AppStyle.Font.iconSymbol)
                    .foregroundColor(AppStyle.Color.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(AppStyle.Color.white)
                Text(subtitle)
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CapsuleToggleStyle(
                    onColor: AppStyle.Color.greenGlow,
                    offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)
                ))
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Seat Settings (step 2)

/// Card-styled "Seat required" toggle row (same border/fill as the name bar).
/// On → seat settings shown; off → hidden.
private struct SeatRequiredBox: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: "chair")
                    .font(AppStyle.Font.iconSymbol)
                    .foregroundColor(AppStyle.Color.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.seatRequiredTitle)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(AppStyle.Color.white)
                Text(L10n.seatRequiredSubtitle)
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CapsuleToggleStyle(
                    onColor: AppStyle.Color.greenGlow,
                    offColor: AppStyle.Color.gray.opacity(AppStyle.Opacity.fadedOverlay)
                ))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }
}

/// A single seat-position row: drag handle (supplied by the parent so it can
/// own the reorder gesture), position label + editable value, and a remove (✕)
/// button. Card style matches the name bar.
private struct SeatSettingTile<Handle: View>: View {
    let position: Int
    @Binding var text: String
    let onRemove: () -> Void
    @ViewBuilder let handle: () -> Handle
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            handle()

            VStack(alignment: .leading, spacing: 2) {
                Text("\(L10n.seatPositionLabel) \(position)")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.secondaryLabel))

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(L10n.seatPositionPlaceholder)
                            .font(AppStyle.Font.sheetSectionLabel)
                            .foregroundColor(AppStyle.Color.white.opacity(AppStyle.Opacity.placeholderText))
                    }
                    TextField("", text: $text)
                        .font(AppStyle.Font.sheetSectionLabel)
                        .foregroundColor(AppStyle.Color.white)
                        .tint(AppStyle.Color.white)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { focused = false }
                }
            }

            Spacer(minLength: 8)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(AppStyle.Font.cardSmallBold)
                    .foregroundColor(AppStyle.Color.green)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().stroke(AppStyle.Color.green.opacity(AppStyle.Opacity.accentStroke), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppStyle.Color.idleCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppStyle.Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }
}

/// Reorderable list of seat-position tiles. Dragging a tile's handle moves it;
/// items animate around the dragged row. Fixed row height keeps the reorder
/// math reliable.
private struct ReorderableSeatList: View {
    @Binding var entries: [SeatEntry]
    let onValueChange: () -> Void
    let onRemove: (SeatEntry.ID) -> Void

    @State private var draggingID: SeatEntry.ID?
    @State private var dragOffset: CGFloat = 0

    private let rowHeight: CGFloat = 66
    private let spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(entries) { entry in
                let isDragging = draggingID == entry.id
                SeatSettingTile(
                    position: (entries.firstIndex(of: entry) ?? 0) + 1,
                    text: binding(for: entry.id),
                    onRemove: { onRemove(entry.id) },
                    handle: {
                        DragHandleDots()
                            .contentShape(Rectangle())
                            .gesture(dragGesture(for: entry.id))
                    }
                )
                .frame(height: rowHeight)
                .offset(y: isDragging ? dragOffset : 0)
                .scaleEffect(isDragging ? 1.02 : 1)
                .shadow(color: Color.black.opacity(isDragging ? 0.4 : 0), radius: 8)
                .zIndex(isDragging ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: entries)
    }

    private func binding(for id: SeatEntry.ID) -> Binding<String> {
        Binding(
            get: { entries.first(where: { $0.id == id })?.value ?? "" },
            set: { newValue in
                if let i = entries.firstIndex(where: { $0.id == id }) {
                    entries[i].value = newValue
                    onValueChange()
                }
            }
        )
    }

    private func dragGesture(for id: SeatEntry.ID) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let from = entries.firstIndex(where: { $0.id == id }) else { return }
                if draggingID == nil { draggingID = id }
                dragOffset = value.translation.height

                let pitch = rowHeight + spacing
                let shift = Int((value.translation.height / pitch).rounded())
                let target = max(0, min(entries.count - 1, from + shift))
                if target != from {
                    let moved = entries.remove(at: from)
                    entries.insert(moved, at: target)
                    dragOffset = value.translation.height - CGFloat(target - from) * pitch
                    onValueChange()
                }
            }
            .onEnded { _ in
                draggingID = nil
                dragOffset = 0
            }
    }
}

/// Six-dot drag-handle glyph; the parent attaches the reorder gesture to it.
private struct DragHandleDots: View {
    var body: some View {
        let dot = AppStyle.Color.green.opacity(AppStyle.Opacity.accentGlyph)
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(dot).frame(width: 3, height: 3)
                    }
                }
            }
        }
    }
}

/// Dashed "Add another seat setting" button (hidden once the max is reached).
private struct AddSeatSettingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.green)
                        .frame(width: 24, height: 24)
                    Image(systemName: "plus")
                        .font(AppStyle.Font.sheetControlGlyph)
                        .foregroundColor(AppStyle.Color.greenBlack)
                }
                Text(L10n.addSeatSetting)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(AppStyle.Color.green)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        AppStyle.Color.green.opacity(AppStyle.Opacity.accentDashedStroke),
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
