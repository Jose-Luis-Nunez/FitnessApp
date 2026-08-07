import CoreGraphics
import Testing
@testable import FitnessTraining

@Suite("Feedback sheet presentation state", .tags(.fast))
struct FeedbackSheetPresentationStateTests {
    @Test func compactHeightTracksUpwardDragAndStopsAtLargeHeight() {
        let state = FeedbackSheetPresentationState()

        #expect(state.height(
            compactHeight: 480,
            largeHeight: 850,
            dragTranslation: -120
        ) == 600)
        #expect(state.height(
            compactHeight: 480,
            largeHeight: 850,
            dragTranslation: -500
        ) == 850)
    }

    @Test func expandedHeightTracksDownwardDragAndStopsAtCompactHeight() {
        let state = FeedbackSheetPresentationState(isExpanded: true)

        #expect(state.height(
            compactHeight: 480,
            largeHeight: 850,
            dragTranslation: 120
        ) == 730)
        #expect(state.height(
            compactHeight: 480,
            largeHeight: 850,
            dragTranslation: 500
        ) == 480)
    }

    @Test func symptomPresenceControlsRestState() {
        var state = FeedbackSheetPresentationState()

        state.synchronizeWithSymptoms(isEmpty: false)
        #expect(state.isExpanded)

        state.synchronizeWithSymptoms(isEmpty: true)
        #expect(!state.isExpanded)
    }

    @Test func upwardDragExpandsFromHeaderAndCompactSurface() {
        var headerState = FeedbackSheetPresentationState()
        var surfaceState = FeedbackSheetPresentationState()

        #expect(headerState.endDrag(translation: -61, source: .header) == .none)
        #expect(headerState.isExpanded)
        #expect(surfaceState.endDrag(
            translation: -41,
            source: .compactSurface
        ) == .none)
        #expect(surfaceState.isExpanded)
    }

    @Test func downwardDragCollapsesExpandedStateThenDismissesCompactState() {
        var state = FeedbackSheetPresentationState(isExpanded: true)

        #expect(state.endDrag(translation: 81, source: .header) == .none)
        #expect(!state.isExpanded)
        #expect(state.endDrag(translation: 81, source: .header) == .dismiss)
    }

    @Test func thresholdBoundariesAndDeadZoneDoNotChangeRestState() {
        var headerState = FeedbackSheetPresentationState()
        var surfaceState = FeedbackSheetPresentationState()
        var expandedState = FeedbackSheetPresentationState(isExpanded: true)

        #expect(headerState.endDrag(translation: -60, source: .header) == .none)
        #expect(!headerState.isExpanded)
        #expect(surfaceState.endDrag(
            translation: -40,
            source: .compactSurface
        ) == .none)
        #expect(!surfaceState.isExpanded)
        #expect(surfaceState.endDrag(translation: 80, source: .header) == .none)
        #expect(!surfaceState.isExpanded)
        #expect(expandedState.endDrag(translation: 80, source: .header) == .none)
        #expect(expandedState.isExpanded)
    }

    @Test func onlyCompactStateMovesTowardDismissal() {
        let compact = FeedbackSheetPresentationState()
        let expanded = FeedbackSheetPresentationState(isExpanded: true)

        #expect(compact.dismissOffset(dragTranslation: 75) == 75)
        #expect(compact.dismissOffset(dragTranslation: -75) == 0)
        #expect(expanded.dismissOffset(dragTranslation: 75) == 0)
    }
}
