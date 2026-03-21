import SwiftUI

private enum BottomTab {
    case home, chart, calendar, profile
}

enum BottomBarRightActionStyle {
    case reset
    case menu
}

struct BottomMenuBarView: View {
    @Binding var navigationPath: NavigationPath
    var showBackButton: Bool = true
    var narrowBy: CGFloat = 50
    var rightActionStyle: BottomBarRightActionStyle = .reset
    var onRightAction: () -> Void = {}
    var customBackAction: (() -> Void)? = nil

    @EnvironmentObject private var overlayState: UIOverlayState

    @State private var selectedTab: BottomTab = .home
    @State private var pillBounce: Bool = false
    @State private var bounceTab: BottomTab? = nil
    @Namespace private var tabNamespace

    private let capsuleHeight: CGFloat = 60
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth - narrowBy)
    }
    private var selectionHeight: CGFloat { capsuleHeight - 8 }
    private let tabForeground = AppStyle.Color.white.opacity(0.98)
    private let tabSelectedForeground = AppStyle.Color.greenGlow
    private let iconSize: CGFloat = 34
    private let bottomOffset: CGFloat = -33
    private let calendarIconScale: CGFloat = 1.18
    private let labelFontSize: CGFloat = 10
    private let circleButtonSize: CGFloat = 44

    var body: some View {
        ZStack(alignment: .bottom) {
            if #available(iOS 26.0, *) {
                glassBody
            } else {
                fallbackBody
            }
        }
        .frame(height: capsuleHeight + 6)
    }

    // MARK: - iOS 26+ (Native Liquid Glass)

    @available(iOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                backButton

                tabBar
                    .frame(height: capsuleHeight)
                    .clipShape(Capsule())
                    .glassEffect(.regular, in: .capsule)

                rightActionButton
            }
            .padding(.horizontal, 8)
            .padding(.bottom, bottomOffset)
        }
    }

    // MARK: - Pre-iOS 26 Fallback

    private var fallbackBody: some View {
        HStack(spacing: 6) {
            backButton

            ZStack {
                LiquidGlassBackground(
                    cornerRadius: capsuleHeight / 2,
                    material: .ultraThinMaterial
                )
                .frame(width: capsuleWidth, height: capsuleHeight)

                tabBar
            }
            .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))

            rightActionButton
        }
        .padding(.horizontal, 8)
        .padding(.bottom, bottomOffset)
    }

    // MARK: - Shared Components

    private var tabBar: some View {
        HStack(spacing: 0) {
            menuItemImage(imageName: "homeIcon", label: "Workout", tab: .home) {
                selectTab(.home)
                navigationPath = NavigationPath()
            }
            menuItemImage(imageName: "analyticsEntry", label: "Analytics", tab: .chart) {
                selectTab(.chart)
                navigationPath = NavigationPath()
                navigationPath.append(NavigationDestination.totalAnalytics)
            }
            menuItemImage(imageName: "menuCalenderIcon", label: "Schedule", tab: .calendar) {
                selectTab(.calendar)
            }
            menuItemImage(imageName: "profileMenuIcon", label: "Profile", tab: .profile) {
                selectTab(.profile)
                navigationPath = NavigationPath()
                navigationPath.append(NavigationDestination.profile)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
    }

    @ViewBuilder
    private var backButton: some View {
        let shouldShow = showBackButton && !navigationPath.isEmpty
        if shouldShow {
            Button(action: {
                if let customAction = customBackAction {
                    customAction()
                } else {
                    navigationPath.removeLast()
                }
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.large)
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .circleGlass(size: circleButtonSize)
            }
            .contentShape(Circle())
            .buttonStyle(.plain)
        } else {
            Circle()
                .fill(Color.clear)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .allowsHitTesting(false)
        }
    }

    private var rightActionButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onRightAction()
        }) {
            Image(systemName: rightActionStyle == .reset ? "arrow.counterclockwise" : "ellipsis")
                .foregroundColor(AppStyle.Color.white)
                .imageScale(.medium)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .circleGlass(size: circleButtonSize)
        }
        .contentShape(Circle())
        .buttonStyle(.plain)
    }

    private func selectTab(_ tab: BottomTab) {
        guard tab != selectedTab else { return }
        withAnimation(.smooth) { selectedTab = tab }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { pillBounce = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounceTab = tab }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pillBounce = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { bounceTab = nil }
        }
    }

    // MARK: - Tab Item

    @ViewBuilder
    private func menuItemImage(imageName: String, label: String, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let targetSize: CGFloat = imageName == "menuCalenderIcon"
            ? iconSize * calendarIconScale
            : (imageName == "analyticsEntry" ? iconSize + 4 : iconSize)

        Button(action: action) {
            VStack(spacing: -2) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: targetSize, height: targetSize)
                    .foregroundColor(isSelected ? tabSelectedForeground : tabForeground)
                    .scaleEffect(bounceTab == tab ? 1.3 : (isSelected ? 1.15 : 1.0))

                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundColor(isSelected ? tabSelectedForeground : tabForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
            .padding(.horizontal, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: selectionHeight)
                        .scaleEffect(y: pillBounce ? 1.4 : 1.0)
                        .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Circle Glass Modifier

private extension View {
    @ViewBuilder
    func circleGlass(size: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .circle)
        } else {
            self.background {
                LiquidGlassBackground(
                    cornerRadius: size / 2,
                    material: .ultraThinMaterial
                )
                .clipShape(Circle())
            }
        }
    }
}
