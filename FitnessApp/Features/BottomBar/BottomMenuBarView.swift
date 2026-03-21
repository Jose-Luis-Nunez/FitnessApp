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

    private let capsuleHeight: CGFloat = 60
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth - narrowBy)
    }
    private var selectionHeight: CGFloat { capsuleHeight - 8 }
    private var selectionBaseWidth: CGFloat { selectionHeight + 30 }
    private let selectionMaterial: Material = .ultraThinMaterial
    private let tabForeground = AppStyle.Color.white.opacity(0.98)
    private let tabSelectedForeground = AppStyle.Color.greenGlow
    private let iconSize: CGFloat = 34
    private let bottomOffset: CGFloat = -33
    private let calendarIconScale: CGFloat = 1.18
    private let labelFontSize: CGFloat = 10
    private let circleButtonSize: CGFloat = 44

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 6) {
                let shouldShowBackButton = showBackButton && !navigationPath.isEmpty
                Group {
                    if shouldShowBackButton {
                        Button(action: {
                            if let customAction = customBackAction {
                                customAction()
                            } else {
                                navigationPath.removeLast()
                            }
                        }) {
                            ZStack {
                                Group {
                                    if #available(iOS 26.0, *) {
                                        Circle()
                                            .fill(Color.clear)
                                            .glassEffect()
                                    } else {
                                        LiquidGlassBackground(
                                            cornerRadius: circleButtonSize / 2,
                                            material: .ultraThinMaterial,
                                            tintOpacity: 0.0,
                                            showsEdgeStroke: false,
                                            showsCaustic: false,
                                            shadowOpacity: 0.20,
                                            lightnessBoostOpacity: 0.12
                                        )
                                        .clipShape(Circle())
                                    }
                                }
                                .overlay(
                                    Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                                )
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppStyle.Color.white)
                                    .imageScale(.large)
                            }
                        }
                        .frame(width: circleButtonSize, height: circleButtonSize)
                        .contentShape(Circle())
                        .buttonStyle(.plain)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: circleButtonSize, height: circleButtonSize)
                            .allowsHitTesting(false)
                    }
                }

                // Glass bar
                ZStack {
                    // Backdrop behind the glass for refraction
                    BackdropHints(barWidth: capsuleWidth, barHeight: capsuleHeight)
                        .frame(width: capsuleWidth, height: capsuleHeight)
                        .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
                        .opacity(0.65)

                    // Native glass on iOS 18+, fallback to custom glass otherwise
                    Group {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous)
                                .fill(Color.clear)
                                .frame(width: capsuleWidth, height: capsuleHeight)
                                .glassEffect()
                        } else {
                            LiquidGlassBackground(
                                cornerRadius: capsuleHeight / 2,
                                material: .ultraThinMaterial,
                                tintOpacity: 0.0,
                                showsEdgeStroke: false,
                                showsCaustic: false,
                                shadowOpacity: 0.20,
                                lightnessBoostOpacity: 0.12
                            )
                            .frame(width: capsuleWidth, height: capsuleHeight)
                        }
                    }

                    HStack(spacing: 12) {
                        // Home uses custom asset and is always white
                        menuItemImage(imageName: "homeIcon", label: "Workout", tab: .home) {
                            selectedTab = .home
                            // Reset to root (Workouts) without pushing a destination,
                            // so the back button stays hidden on the root screen
                            navigationPath = NavigationPath()
                        }

                        // Analytics uses custom asset
                        menuItemImage(imageName: "analyticsEntry", label: "Analytics", tab: .chart) {
                            selectedTab = .chart
                            navigationPath = NavigationPath()
                            navigationPath.append(NavigationDestination.totalAnalytics)
                        }

                        menuItemImage(imageName: "menuCalenderIcon", label: "Schedule", tab: .calendar) {
                            selectedTab = .calendar
                        }

                        menuItemImage(imageName: "profileMenuIcon", label: "Profile", tab: .profile) {
                            selectedTab = .profile
                            navigationPath = NavigationPath()
                            navigationPath.append(NavigationDestination.profile)
                        }
                    }
                    .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
                }
                .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
                
                // Right circular action for context dependent actions
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRightAction()
                }) {
                    ZStack {
                        Group {
                            if #available(iOS 26.0, *) {
                                Circle()
                                    .fill(Color.clear)
                                    .glassEffect()
                            } else {
                                LiquidGlassBackground(
                                    cornerRadius: circleButtonSize / 2,
                                    material: .ultraThinMaterial,
                                    tintOpacity: 0.0,
                                    showsEdgeStroke: false,
                                    showsCaustic: false,
                                    shadowOpacity: 0.20,
                                    lightnessBoostOpacity: 0.12
                                )
                                .clipShape(Circle())
                            }
                        }
                        .overlay(
                            Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                        )
                        Image(systemName: rightActionStyle == .reset ? "arrow.counterclockwise" : "ellipsis")
                            .foregroundColor(AppStyle.Color.white)
                            .imageScale(.medium)
                    }
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            // Zusätzlicher seitlicher Abstand, damit runde Buttons nicht am Rand schneiden
            .padding(.horizontal, 8)
            // Position näher am unteren Rand
            .padding(.bottom, bottomOffset)
        }
        // Nur so hoch wie die Kapsel – kein abgetrennter Hintergrundbereich
        .frame(height: capsuleHeight + 6)
    }

    @ViewBuilder
    private func menuItemImage(imageName: String, label: String, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let targetSize: CGFloat = imageName == "menuCalenderIcon"
            ? iconSize * calendarIconScale
            : (imageName == "analyticsEntry" ? iconSize + 4 : iconSize)

        Button(action: action) {
            VStack(spacing: 2) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: targetSize, height: targetSize)
                    .foregroundColor(isSelected ? tabSelectedForeground : tabForeground)
                
                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundColor(isSelected ? tabSelectedForeground : tabForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
            .padding(.horizontal, 2)
            .background(alignment: .center) {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                        .fill(selectionMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .frame(width: selectionBaseWidth + 6, height: selectionHeight)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

