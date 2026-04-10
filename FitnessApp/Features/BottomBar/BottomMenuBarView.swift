import SwiftUI
import FitnessUI
import FitnessExercise

private enum BottomTab {
    case home, chart, calendar, profile
}

struct BottomMenuBarView: View {
    var showBackButton: Bool = true
    var narrowBy: CGFloat = 50
    var onRightAction: () -> Void = {}
    var customBackAction: (() -> Void)? = nil

    @Environment(AppRouter.self) private var router

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
    private let circleButtonSize: CGFloat = 44

    private var selectedTab: BottomTab {
        switch router.currentScene {
        case .workouts, .home, .category, .training: return .home
        case .schedule:                               return .calendar
        case .profile:                                return .profile
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
        .frame(height: capsuleHeight + 6)
    }

    // MARK: - Shared Components

    private var tabBar: some View {
        HStack(spacing: 0) {
            menuItemImage(imageName: "homeIcon", label: "Workout", tab: .home) {
                animateTabBounce(.home)
                router.popToRoot()
            }
            menuItemImage(imageName: "analyticsEntry", label: "Analytics", tab: .chart) {
                animateTabBounce(.chart)
                router.switchToAnalytics()
            }
            menuItemImage(imageName: "menuCalenderIcon", label: "Schedule", tab: .calendar) {
                animateTabBounce(.calendar)
                router.switchToSchedule()
            }
            menuItemImage(imageName: "profileMenuIcon", label: "Profile", tab: .profile) {
                animateTabBounce(.profile)
                router.switchToProfile()
            }
        }
        .padding(.horizontal, 4)
        .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
    }

    @ViewBuilder
    private var backButton: some View {
        let shouldShow = showBackButton && !router.isEmpty
        if shouldShow {
            Button(action: {
                if let customAction = customBackAction {
                    customAction()
                } else {
                    router.pop()
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
            Image(systemName: "ellipsis")
                .foregroundColor(AppStyle.Color.white)
                .imageScale(.medium)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .circleGlass(size: circleButtonSize)
        }
        .contentShape(Circle())
        .buttonStyle(.plain)
    }

    private func animateTabBounce(_ tab: BottomTab) {
        guard tab != selectedTab else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { pillBounce = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounceTab = tab }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { pillBounce = false }
            try? await Task.sleep(for: .milliseconds(50))
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
                    .font(AppStyle.Font.chartAxisSmall)
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
    func circleGlass(size: CGFloat) -> some View {
        self.glassEffect(.regular, in: .circle)
    }
}
