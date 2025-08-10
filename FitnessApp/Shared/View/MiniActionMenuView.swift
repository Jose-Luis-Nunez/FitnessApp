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
    var minHeight: CGFloat = 140
    private let rowHeight: CGFloat = 56 // visual height per item including inner paddings

    private var visibleItemCount: Int {
        items.filter { !($0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.icon == nil) }.count
    }

    // Ensures: at least 2 rows worth of height; grows by one row per extra item
    private var effectiveMinHeight: CGFloat {
        let rows = max(visibleItemCount, 2)
        let extraRows = max(0, rows - 2)
        return minHeight + CGFloat(extraRows) * rowHeight
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                headerView
                itemsView
            }
            .padding(14) // internal padding so bottom edge stays fixed
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
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }
    
}


