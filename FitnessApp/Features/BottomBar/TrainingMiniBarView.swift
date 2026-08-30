import SwiftUI
import FitnessCore
import FitnessUI
import FitnessExercise
import FitnessTraining
import FitnessResources

/// Minimal "return to what you were doing" affordance, modelled on the Netflix
/// mini player: a chevron plus the exercise name, sitting directly above the
/// tab capsule. It shows only while an exercise is still in progress — the same
/// state the cards mark with their in-progress icon.
///
/// With several exercises running it opens on the most recently used one and
/// pages through the rest. Paging only changes what is displayed; the up-chevron
/// and the title are what resume the exercise currently shown.
struct TrainingMiniBarView: View {
    /// Most recently opened first.
    let targets: [ActiveTrainingTarget]

    @Environment(AppRouter.self) private var router

    /// `nil` means "follow the head of the list".
    ///
    /// Selected by id, never by index: an index kept across a list change points
    /// at a different exercise once a session ends, and the up-chevron would then
    /// resume the wrong one. The index is derived on every render instead.
    ///
    /// The lifetime of this state *is* the reset policy. The bar's `if` in
    /// `BottomMenuBarView` tears the view down whenever the list empties, the
    /// training sheet opens, or the scene changes — so the bar always comes back
    /// showing the most recent exercise, which is the agreed behaviour. Do not
    /// pin identity with `.id(...)`: keying it on the list head would throw the
    /// user off their chosen exercise every time a session starts elsewhere.
    @State private var selectedExerciseID: Exercise.ID?

    private let chevronSize: CGFloat = 15
    /// The chevron is a separate affordance from the name, not an accent on it —
    /// with no gap the two read as one glyph-plus-label lockup.
    private let contentSpacing: CGFloat = 5
    private let indicatorTopSpacing: CGFloat = 8
    private let indicatorWidth: CGFloat = 150
    private let stepArrowSize: CGFloat = 17
    /// Far enough that a tap that drifts slightly is still a tap, short enough
    /// that a deliberate flick registers without travelling across the bar.
    private let swipeMinimumDistance: CGFloat = 20

    private var index: Int {
        targets.firstIndex { $0.exercise.id == selectedExerciseID } ?? 0
    }

    private var current: ActiveTrainingTarget? {
        guard targets.indices.contains(index) else { return nil }
        return targets[index]
    }

    private var isPageable: Bool { targets.count > 1 }

    var body: some View {
        if let current {
            VStack(spacing: indicatorTopSpacing) {
                HStack(spacing: 0) {
                    stepButton(.backward, isEnabled: index > 0)

                    Spacer(minLength: 0)

                    resumeButton(for: current)

                    Spacer(minLength: 0)

                    stepButton(.forward, isEnabled: index < targets.count - 1)
                }
                .frame(maxWidth: .infinity)

                if isPageable {
                    PageSegmentIndicator(
                        count: targets.count,
                        index: index,
                        width: indicatorWidth
                    )
                }
            }
            .padding(.horizontal, AppStyle.Layout.cardHorizontalPadding)
            // The whole bar is the swipe surface, which is why the resume button
            // is sized to its glyph and label rather than filling the row: the
            // space either side of the title has to stay free for the gesture.
            // A minimum distance keeps taps on the buttons working.
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            // Drops a selection whose exercise is gone, so a cancelled-then-
            // restarted exercise cannot silently snap the bar back to itself.
            .onChange(of: targets.map(\.exercise.id)) { _, ids in
                if let selectedExerciseID, !ids.contains(selectedExerciseID) {
                    self.selectedExerciseID = nil
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: swipeMinimumDistance)
            .onEnded { value in
                guard isPageable else { return }
                // Swiping left pulls the next exercise in from the right, the
                // way a carousel moves.
                step(value.translation.width < 0 ? .forward : .backward)
            }
    }

    /// The only part that opens anything. Kept separate from the step buttons so
    /// paging cannot present the training sheet, and deliberately sized to its
    /// content — a full-width tap target would swallow the swipe surface.
    private func resumeButton(for target: ActiveTrainingTarget) -> some View {
        Button {
            Haptics.impact(.light)
            router.presentTraining(
                exerciseId: target.exercise.id,
                category: target.group
            )
        } label: {
            VStack(spacing: contentSpacing) {
                Image(systemName: "chevron.up")
                    .font(.system(size: chevronSize, weight: .semibold))
                Text(target.exercise.name)
                    .font(AppStyle.Font.cardBoldTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(AppStyle.Color.white)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(FitnessCore.BottomBarIDs.trainingMiniBar)
        .accessibilityLabel(Text(target.exercise.name))
    }

    private enum StepDirection {
        case backward, forward

        var iconName: String {
            switch self {
            case .backward: "chevron.left"
            case .forward: "chevron.right"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .backward: FitnessCore.BottomBarIDs.trainingMiniBarPrevious
            case .forward: FitnessCore.BottomBarIDs.trainingMiniBarNext
            }
        }

        var accessibilityLabel: LocalizedStringResource {
            switch self {
            case .backward: AppText.accessibilityPreviousActiveExercise
            case .forward: AppText.accessibilityNextActiveExercise
            }
        }
    }

    /// Muted against the white up-chevron on purpose: stepping and resuming are
    /// different actions and must not look alike. Clamped rather than wrapping —
    /// the continuous indicator reads as a bounded range, so running off its end
    /// back to the start would contradict it.
    @ViewBuilder
    private func stepButton(_ direction: StepDirection, isEnabled: Bool) -> some View {
        if isPageable {
            Button {
                step(direction)
            } label: {
                Image(systemName: direction.iconName)
                    .font(.system(size: stepArrowSize, weight: .semibold))
                    .foregroundColor(AppStyle.Color.idleMetricUnit)
                    .opacity(isEnabled ? 1 : AppStyle.Opacity.disabledElement)
                    // The app's other chevron pairs leave the tap area at the
                    // glyph. Not repeated here.
                    .frame(
                        width: AppStyle.Layout.minimumTapTargetSize,
                        height: AppStyle.Layout.minimumTapTargetSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityLabel(Text(direction.accessibilityLabel))
            .accessibilityIdentifier(direction.accessibilityIdentifier)
        }
    }

    private func step(_ direction: StepDirection) {
        let next = direction == .backward ? index - 1 : index + 1
        guard targets.indices.contains(next) else { return }
        Haptics.impact(.light)
        selectedExerciseID = targets[next].exercise.id
    }
}
