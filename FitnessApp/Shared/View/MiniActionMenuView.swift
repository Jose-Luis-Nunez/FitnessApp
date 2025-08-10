import SwiftUI

struct MiniActionMenuItem: Identifiable {
    let id = UUID()
    let icon: String?
    let title: String
    let isDestructive: Bool
    let action: () -> Void
}

struct MiniActionMenuView: View {
    let title: String?
    let items: [MiniActionMenuItem]
    var width: CGFloat = min(UIScreen.main.bounds.width * 0.55, 320)
    var minHeight: CGFloat = 140 // legacy default; final height computed below
    private let rowHeight: CGFloat = 52

    private var visibleItemCount: Int {
        items.filter { !($0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.icon == nil) }.count
    }

    // Ensures: at least 2 rows worth of height; grows by exact row increments
    private var effectiveMinHeight: CGFloat {
        let rows = max(visibleItemCount, 2)
        return headerHeight + CGFloat(rows) * rowHeight + (contentVerticalPadding * 2)
    }

    private var contentVerticalPadding: CGFloat { 14 }
    private var headerHeight: CGFloat { title == nil ? 0 : 56 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                headerView
                itemsView
            }
            .padding(.horizontal, 14)
            .padding(.vertical, contentVerticalPadding) // internal padding so bottom edge stays fixed
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
        // Skip placeholders entirely for layout; height is controlled by effectiveMinHeight
        if (item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && item.icon == nil {
            EmptyView()
        } else {
            Button(action: item.action) {
                HStack(spacing: 12) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                    }
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
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


