import SwiftUI

/// Labeled metric column for card metric rows.
///
/// Renders a label aligned to `.metricLabel` above caller-provided value
/// content and an optional footer row. Wraps in `.contentShape(Rectangle())`
/// and an optional tap gesture so the entire column is tappable.
///
/// Used by `IdleActiveCardModelView` for the Weight and Seat columns;
/// intentionally not used for columns that diverge from this pattern
/// (e.g. `progressColumn` has different spacing; coaching tip is inline with the title).
public struct MetricColumnView<Content: View, Footer: View>: View {
    let label: String
    let alignment: HorizontalAlignment
    let onTap: (() -> Void)?
    let content: Content
    let footer: Footer

    public init(
        label: String,
        alignment: HorizontalAlignment = .leading,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.label = label
        self.alignment = alignment
        self.onTap = onTap
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(AppStyle.Font.metricLabel)
                .foregroundColor(AppStyle.Color.idleMetricLabel)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            content
            footer
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

public extension MetricColumnView where Footer == EmptyView {
    init(
        label: String,
        alignment: HorizontalAlignment = .leading,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(label: label, alignment: alignment, onTap: onTap, content: content) {
            EmptyView()
        }
    }
}
