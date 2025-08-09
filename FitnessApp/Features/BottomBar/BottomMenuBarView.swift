import SwiftUI

private enum BottomTab {
    case home, chart, calendar, profile
}

struct BottomMenuBarView: View {
    let barHeight: CGFloat
    let onAddExercise: () -> Void
    let backgroundColor: Color
    @Binding var navigationPath: NavigationPath

    @State private var selectedTab: BottomTab = .home

    private var capsuleHeight: CGFloat { max(48, barHeight * 1.6) }
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding // unify margins with other bars
    private var capsuleWidth: CGFloat { UIScreen.main.bounds.width - (2 * sideMargin) }
    // Liquid Glass tuning
    private let barTintOpacity: Double = 0.02
    private let selectionHeight: CGFloat = 36
    private let iconSize: CGFloat = 24
    // Position tweak: negative moves the bar closer to the device bottom edge
    private let bottomOffset: CGFloat = -40
    private let calendarIconScale: CGFloat = 1.18

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep only the glass bar where the icons live (no extra layers behind)
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

                HStack(spacing: 24) {
                    menuItem(icon: "house", tab: .home) {
                        selectedTab = .home
                        navigationPath = NavigationPath()
                        navigationPath.append(NavigationDestination.workouts)
                    }

                    menuItem(icon: "chart.bar", tab: .chart) {
                        selectedTab = .chart
                    }

                    menuItemImage(imageName: "menuCalenderIcon", tab: .calendar) {
                        selectedTab = .calendar
                    }

                    menuItem(icon: "person", tab: .profile) {
                        selectedTab = .profile
                        navigationPath = NavigationPath()
                        navigationPath.append(NavigationDestination.profile)
                    }
                }
                .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
            }
            .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
            // Position näher am unteren Rand
            .padding(.bottom, bottomOffset)
        }
        // Nur so hoch wie die Kapsel – kein abgetrennter Hintergrundbereich
        .frame(height: capsuleHeight + 6)
    }

    @ViewBuilder
    private func menuItem(icon: String, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let baseForeground = AppStyle.Color.white.opacity(0.98)
        let selectedForeground = AppStyle.Color.green

        Button(action: action) {
            ZStack {
                if isSelected {
                    LiquidGlassSelection(height: selectionHeight)
                        .frame(height: selectionHeight)
                }

                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(isSelected ? selectedForeground : baseForeground)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func menuItemImage(imageName: String, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let baseForeground = AppStyle.Color.white.opacity(0.98)
        let selectedForeground = AppStyle.Color.green
        let targetSize = imageName == "menuCalenderIcon" ? iconSize * calendarIconScale : iconSize

        Button(action: action) {
            ZStack {
                if isSelected {
                    LiquidGlassSelection(height: selectionHeight)
                        .frame(height: selectionHeight)
                }

                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: targetSize, height: targetSize)
                    .foregroundColor(isSelected ? selectedForeground : baseForeground)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

