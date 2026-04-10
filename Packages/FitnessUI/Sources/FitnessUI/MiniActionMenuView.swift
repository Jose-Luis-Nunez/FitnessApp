import SwiftUI

public struct MiniActionMenuItem: Identifiable {
    public let id = UUID()
    public let icon: String?
    public let title: String
    public let isDestructive: Bool
    public let action: () -> Void

    public init(icon: String?, title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}

public struct MiniActionMenuView: View {
    let title: String?
    let items: [MiniActionMenuItem]
    var width: CGFloat
    var minHeight: CGFloat
    private let rowHeight: CGFloat = 52

    public init(title: String?, items: [MiniActionMenuItem], width: CGFloat? = nil, minHeight: CGFloat = 140) {
        self.title = title
        self.items = items
        #if canImport(UIKit)
        self.width = width ?? min(UIScreen.main.bounds.width * 0.55, 320)
        #else
        self.width = width ?? 280
        #endif
        self.minHeight = minHeight
    }

    private var visibleItemCount: Int {
        items.filter { !($0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.icon == nil) }.count
    }

    private var effectiveMinHeight: CGFloat {
        let rows = max(visibleItemCount, 2)
        return headerHeight + CGFloat(rows) * rowHeight + (contentVerticalPadding * 2)
    }

    private var contentVerticalPadding: CGFloat { 14 }
    private var headerHeight: CGFloat { title == nil ? 0 : 56 }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.4))
                )

            VStack(spacing: 0) {
                headerView
                itemsView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, contentVerticalPadding)
        }
        .frame(width: width)
        .frame(height: effectiveMinHeight, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    @ViewBuilder
    private var headerView: some View {
        if let title = title {
            VStack(spacing: 8) {
                Text(title)
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private var itemsView: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                itemRow(item: items[idx])
            }
        }
    }

    @ViewBuilder
    private func itemRow(item: MiniActionMenuItem) -> some View {
        if (item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && item.icon == nil {
            EmptyView()
        } else {
            Button(action: item.action) {
                HStack(spacing: 12) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(AppStyle.Font.regularChip)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    Text(item.title)
                        .font(AppStyle.Font.regularChip)
                        .foregroundColor(.white)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(height: rowHeight)
            }
            .buttonStyle(.plain)
        }
    }
}
