import SwiftUI

/// Labeled metric column for card metric rows.
///
/// Renders a label aligned to `.metricLabel` above caller-provided value
/// content. Wraps in `.contentShape(Rectangle())` and an optional tap
/// gesture so the entire column is tappable.
///
/// Used by `IdleActiveCardModelView` for the Weight and Seat columns;
/// intentionally not used for columns that diverge from this pattern
/// (e.g. `progressColumn` has different spacing, `tipColumn` has no label).
public struct MetricColumnView<Content: View>: View {
    let label: String
    let onTap: (() -> Void)?
    let content: Content

    public init(
        label: String,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.onTap = onTap
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(AppStyle.Font.metricLabel)
                .foregroundColor(AppStyle.Color.idleMetricLabel)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            content
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
