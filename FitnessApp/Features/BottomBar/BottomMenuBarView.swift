import SwiftUI

private enum BottomTab {
    case home, chart, calendar, profile
}

enum BottomBarRightActionStyle {
    case reset
    case menu
}

struct BottomMenuBarView: View {
    let barHeight: CGFloat
    let onAddExercise: () -> Void
    let backgroundColor: Color
    @Binding var navigationPath: NavigationPath
    var showBackButton: Bool = true
    var narrowBy: CGFloat = 50 // reduce overall bar width by this many points (made 10pt narrower)
    var rightActionStyle: BottomBarRightActionStyle = .reset
    var onRightAction: () -> Void = {}
    var customBackAction: (() -> Void)? = nil // Custom back action for special cases

    @EnvironmentObject private var overlayState: UIOverlayState

    @State private var selectedTab: BottomTab = .home

    private var capsuleHeight: CGFloat { max(48, barHeight * 1.6) }
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding // unify margins with other bars
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth - narrowBy)
    }
    // Liquid Glass tuning
    private let barTintOpacity: Double = 0.02
    // Selection pill sizing - matching Filter Toggle (3px padding all sides)
    private var selectionHeight: CGFloat { capsuleHeight - 6 }
    private var selectionBaseWidth: CGFloat { selectionHeight * 1.4 }
    private let selectionFill = Color.white.opacity(0.12)
    private let iconSize: CGFloat = 22
    private let iconBoost: CGFloat = 10 // increase all icons uniformly by +10pt
    // Position tweak: negative moves the bar closer to the device bottom edge
    private let bottomOffset: CGFloat = -40
    private let calendarIconScale: CGFloat = 1.18
    private let labelFontSize: CGFloat = 10 // iOS standard tab bar label size

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
                                            cornerRadius: 22,
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
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .buttonStyle(.plain)
                    } else {
                        // Placeholder to keep bar and right action in identical horizontal positions
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
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
                                    cornerRadius: 22,
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
                    .frame(width: 44, height: 44)
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
    private func menuItem(icon: String, tab: BottomTab, selectedColorOverride: Color? = nil, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let baseForeground = AppStyle.Color.white.opacity(0.98)
        let selectedForeground = AppStyle.Color.white.opacity(0.98)
        let resolvedSelected = selectedColorOverride ?? selectedForeground

        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                    .frame(width: iconSize + iconBoost, height: iconSize + iconBoost)
                .foregroundColor(isSelected ? resolvedSelected : baseForeground)
                .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
                .padding(.horizontal, 6)
                .background(alignment: .center) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                            .fill(selectionFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .frame(width: selectionBaseWidth, height: selectionHeight)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuItemImage(imageName: String, label: String, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let baseForeground = AppStyle.Color.white.opacity(0.98)
        let selectedForeground = AppStyle.Color.white.opacity(0.98)
        // Icon sizes with boost
        let baseIconSize: CGFloat = iconSize + iconBoost
        let targetSize = imageName == "menuCalenderIcon"
            ? baseIconSize * calendarIconScale
            : (imageName == "analyticsEntry" ? baseIconSize + 4 : baseIconSize)

        Button(action: action) {
            VStack(spacing: 2) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: targetSize, height: targetSize)
                    .foregroundColor(isSelected ? selectedForeground : baseForeground)
                
                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundColor(isSelected ? selectedForeground : baseForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
            .padding(.horizontal, 2)
            .background(alignment: .center) {
                if isSelected {
                    RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                        .fill(selectionFill)
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

