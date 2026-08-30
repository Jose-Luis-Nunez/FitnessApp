import SwiftUI

/// One continuous track with a single highlighted segment marking the current
/// position — the bar under the training mini bar's title.
///
/// A segment rather than dots: the mini bar can hold a handful of running
/// exercises, and a row of dots at that size reads as decoration, while a
/// filled slice of a bounded track shows both how many there are and how far
/// along you are. `ProgressBar` cannot be reused for this; it fills from the
/// leading edge instead of moving a fixed-width slice.
public struct PageSegmentIndicator: View {
    public let count: Int
    public let index: Int
    public let width: CGFloat

    private let height: CGFloat = AppStyle.Layout.grabberHeight

    public init(count: Int, index: Int, width: CGFloat) {
        self.count = count
        self.index = index
        self.width = width
    }

    private var segmentWidth: CGFloat {
        guard count > 0 else { return width }
        return width / CGFloat(count)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppStyle.Color.progressTrackGrey)
                .frame(width: width, height: height)

            Capsule()
                .fill(AppStyle.Color.white)
                .frame(width: segmentWidth, height: height)
                .offset(x: segmentWidth * CGFloat(max(0, min(index, count - 1))))
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}
