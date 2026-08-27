import Testing
import CoreGraphics
@testable import FitnessTraining
import FitnessTestSupport

/// The latch decides which measurement the feedback sheet and the Less/More
/// picker are sized from. Both regressed on this rule before it was a type, so
/// each clause is pinned here rather than left to the view that feeds it.
@Suite("TrainingSheetHeightLatch", .tags(.fast))
struct TrainingSheetHeightLatchTests {

    @Test func startsAtTheFallbackHeight() {
        #expect(TrainingSheetHeightLatch().height == TrainingSheetHeightLatch.fallbackHeight)
    }

    @Test func recordsAMeasurementTakenWithNoOverlayPresented() {
        var sut = TrainingSheetHeightLatch()
        sut.record(412, overlayPresented: false)
        #expect(sut.height == 412)
    }

    /// The regression this type exists for: the training sheet loses its action
    /// bar while a set is edited, so a measurement taken then describes a sheet
    /// that is short *because* the picker is open.
    @Test func ignoresAMeasurementTakenWhileAnOverlayIsPresented() {
        var sut = TrainingSheetHeightLatch()
        sut.record(412, overlayPresented: false)
        sut.record(310, overlayPresented: true)
        #expect(sut.height == 412)
    }

    @Test func releasesOnceTheOverlayIsGone() {
        var sut = TrainingSheetHeightLatch()
        sut.record(412, overlayPresented: false)
        sut.record(310, overlayPresented: true)
        sut.record(430, overlayPresented: false)
        #expect(sut.height == 430)
    }

    /// A collapsed or not-yet-laid-out sheet reports zero. Keeping the last good
    /// height beats clamping to a hairline, which would collapse every sibling.
    @Test(arguments: [CGFloat(0), -1, -400])
    func ignoresNonPositiveMeasurements(_ measured: CGFloat) {
        var sut = TrainingSheetHeightLatch()
        sut.record(412, overlayPresented: false)
        sut.record(measured, overlayPresented: false)
        #expect(sut.height == 412)
    }

    @Test func keepsTheFallbackWhenTheFirstMeasurementIsInvalid() {
        var sut = TrainingSheetHeightLatch()
        sut.record(0, overlayPresented: false)
        #expect(sut.height == TrainingSheetHeightLatch.fallbackHeight)
    }
}
