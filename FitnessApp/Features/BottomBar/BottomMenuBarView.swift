import SwiftUI
import FitnessCore
import FitnessUI
import FitnessExercise
import FitnessResources

private enum BottomTab {
    case workouts, training, chart, calendar, profile

    var accessibilityIdentifier: String {
        switch self {
        case .workouts: FitnessCore.BottomBarIDs.workoutsTab
        case .training: FitnessCore.BottomBarIDs.trainingTab
        case .chart: FitnessCore.BottomBarIDs.analyticsTab
        case .calendar: FitnessCore.BottomBarIDs.scheduleTab
        case .profile: FitnessCore.BottomBarIDs.profileTab
        }
    }
}

struct BottomMenuBarView: View {
    var showBackButton: Bool = true
    // `narrowBy` reserves horizontal room for the two side circle buttons by
    // shrinking the centre tab capsule. It scales with `circleButtonSize`:
    // growing a button by X each side means widening `narrowBy` by 2·X so the
    // overall row width (and side margins) stay put.
    var narrowBy: CGFloat = 74
    var onRightAction: () -> Void = {}
    var onTrainingTab: () -> Void = {}
    var customBackAction: (() -> Void)? = nil

    @Environment(AppRouter.self) private var router
    @Environment(UIOverlayState.self) private var overlayState
    @Environment(\.appColorTheme) private var appColorTheme

    @State private var pillBounce: Bool = false
    @State private var bounceTab: BottomTab? = nil
    @Namespace private var tabNamespace

    private let capsuleHeight: CGFloat = 60
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth - narrowBy)
    }
    /// Icon-only tabs: the selection pill is inset only vertically (the bar's own
    /// 4pt horizontal padding already provides the side gap at the ends), so it
    /// fills the tab-cell width and reads as a wide horizontal pill.
    private let selectionVerticalInset: CGFloat = 4
    private let tabForeground = AppStyle.Color.white.opacity(0.98)
    private var tabSelectedForeground: Color { appColorTheme.accent.glow }
    private let iconSize: CGFloat = 30
    private let bottomOffset: CGFloat = -33
    private let calendarIconScale: CGFloat = 1.18
    // Side circle buttons (back / ellipsis). Kept just under `capsuleHeight` so
    // they read as a balanced trio with the tab capsule while giving a large,
    // easy-to-hit target. Paired with `narrowBy` (see above).
    private let circleButtonSize: CGFloat = 56

    private var selectedTab: BottomTab {
        switch router.currentScene {
        case .workouts:                    return .workouts
        // Being inside a workout (category selection or a category)
        // lights the "Training" tab — the "Workouts" tab only lights on the list.
        case .home, .category:             return .training
        case .analytics:                   return .chart
        case .schedule:                    return .calendar
        case .profile:                     return .profile
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            bottomBarSurfaceContent
        }
        .frame(height: capsuleHeight + 6)
    }

    @ViewBuilder
    private var bottomBarSurfaceContent: some View {
        if #available(iOS 27.0, *) {
            GlassEffectContainer(spacing: 6) {
                bottomBarControls
            }
        } else {
            bottomBarControls
        }
    }

    @ViewBuilder
    private var bottomBarControls: some View {
        if overlayState.exerciseSelectionMode != .none {
            selectionActionBar
                .padding(.horizontal, 8)
                .padding(.bottom, bottomOffset)
        } else {
            HStack(spacing: 6) {
                backButton

                tabBar
                    .frame(height: capsuleHeight)
                    .clipShape(Capsule())
                    .bottomMenuSurface(in: .capsule)

                rightActionButton
            }
            .padding(.horizontal, 8)
            .padding(.bottom, bottomOffset)
        }
    }

    /// Multi-select morph: replaces the whole home bar the moment radio buttons
    /// appear (`exerciseSelectionMode != .none`). With nothing ticked it shows
    /// only **Cancel**; once ≥1 is selected it becomes **Cancel | Deactivate**
    /// (or **Activate**). Same dimensions as the normal bar so the layout never jumps.
    private var selectionActionBar: some View {
        let actionLabel = overlayState.exerciseSelectionMode == .activate
            ? AppText.exerciseActivateSelection
            : AppText.exerciseDeactivateSelection
        let hasSelection = !overlayState.selectedExerciseIds.isEmpty

        return HStack(spacing: 0) {
            Button(action: {
                Haptics.impact(.light)
                overlayState.endExerciseSelection()
            }) {
                Text(AppText.actionCancel)
                    .font(AppStyle.Font.cardValueBold)
                    .foregroundColor(AppStyle.Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hasSelection {
                Rectangle()
                    .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionDivider))
                    .frame(width: 1, height: capsuleHeight * 0.5)

                Button(action: {
                    Haptics.impact(.medium)
                    overlayState.commitExerciseSelection = true
                }) {
                    Text(actionLabel)
                        .font(AppStyle.Font.cardValueBold)
                        .foregroundColor(appColorTheme.accent.glow)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: capsuleHeight)
        .clipShape(Capsule())
        .bottomMenuSurface(in: .capsule)
    }

    // MARK: - Shared Components

    private var tabBar: some View {
        HStack(spacing: 0) {
            menuItemImage(imageName: "homeIcon", label: AppText.workoutTab, tab: .workouts) {
                animateTabBounce(.workouts)
                router.popToRoot()
            }
            // Placeholder icon until a dedicated "Training" asset exists.
            menuItemImage(imageName: "dumbbell.fill", isSystemImage: true, label: AppText.trainingTitle, tab: .training) {
                animateTabBounce(.training)
                onTrainingTab()
            }
            menuItemImage(imageName: "analyticsEntry", label: AppText.analyticsTitle, tab: .chart) {
                animateTabBounce(.chart)
                router.switchToAnalytics()
            }
            menuItemImage(imageName: "menuCalenderIcon", label: AppText.scheduleTitle, tab: .calendar) {
                animateTabBounce(.calendar)
                router.switchToSchedule()
            }
            menuItemImage(imageName: "profileMenuIcon", label: AppText.profileTitle, tab: .profile) {
                animateTabBounce(.profile)
                router.switchToProfile()
            }
        }
        .padding(.horizontal, 4)
        .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
    }

    /// The back button is meaningful while navigating the workout flow. Opening
    /// a workout from the list pushes `.home`, so its category selection must
    /// offer a way back to that list.
    private var isDrillDownScene: Bool {
        switch router.currentScene {
        case .home:
            return router.trainingPresentation != nil
                || router.isHomePushedFromWorkoutList
        case .category: return true
        case .workouts: return router.trainingPresentation != nil
        case .analytics, .schedule, .profile: return false
        }
    }

    @ViewBuilder
    private var backButton: some View {
        let shouldShow = showBackButton && isDrillDownScene
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
                    .circleGlass()
                    // contentShape must live INSIDE the label (last modifier) so
                    // it survives .buttonStyle(.plain) recomposing the label —
                    // otherwise the hit area collapses to the drawn glyph. Mirrors
                    // the selectionActionBar buttons.
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(FitnessCore.BottomBarIDs.backButton)
        } else {
            Circle()
                .fill(Color.clear)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .allowsHitTesting(false)
        }
    }

    /// The ellipsis (mini-menu) button only exists on scenes that actually have
    /// a contextual menu — the workout flow (`.workouts`, `.home`, `.category`).
    /// The top-level tab destinations Analytics, Schedule and
    /// Profile have no such menu, so the button is hidden there (a clear
    /// placeholder keeps the tab capsule centred).
    private var showsRightAction: Bool {
        switch router.currentScene {
        case .workouts, .home, .category: return true
        case .analytics, .schedule, .profile:        return false
        }
    }

    @ViewBuilder
    private var rightActionButton: some View {
        if showsRightAction {
            Button(action: {
                Haptics.impact(.light)
                onRightAction()
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.large)
                    .frame(width: circleButtonSize, height: circleButtonSize)
                    .circleGlass()
                    // contentShape must live INSIDE the label (last modifier) so it
                    // survives .buttonStyle(.plain) recomposing the label — otherwise
                    // the hit area collapses to the thin ellipsis glyph. Mirrors the
                    // selectionActionBar buttons.
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppText.commonActions)
            .accessibilityIdentifier(FitnessCore.BottomBarIDs.contextMenu)
        } else {
            Circle()
                .fill(Color.clear)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .allowsHitTesting(false)
        }
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
    private func menuItemImage(imageName: String, isSystemImage: Bool = false, label: LocalizedStringResource, tab: BottomTab, action: @escaping () -> Void) -> some View {
        let isSelected = selectedTab == tab
        let targetSize: CGFloat = imageName == "menuCalenderIcon"
            ? iconSize * calendarIconScale
            : (imageName == "analyticsEntry" ? iconSize + 4 : iconSize)

        Button(action: action) {
            tabIcon(imageName: imageName, isSystemImage: isSystemImage)
                .frame(width: targetSize, height: targetSize)
                .foregroundColor(isSelected ? tabSelectedForeground : tabForeground)
                .scaleEffect(bounceTab == tab ? 1.3 : (isSelected ? 1.15 : 1.0))
                .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AppStyle.Color.white.opacity(AppStyle.Opacity.selectionTintFill))
                            .padding(.vertical, selectionVerticalInset)
                            .scaleEffect(pillBounce ? 1.4 : 1.0)
                            .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    @ViewBuilder
    private func tabIcon(imageName: String, isSystemImage: Bool) -> some View {
        if isSystemImage {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
        } else {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Circle Glass Modifier

private extension View {
    func circleGlass() -> some View {
        self.bottomMenuSurface(in: .circle)
    }

    /// iOS 26 omits the surrounding `GlassEffectContainer`; the direct surface
    /// remains shared with the List/Muscle filter toggle on every OS version.
    @ViewBuilder
    func bottomMenuSurface<S: InsettableShape>(in shape: S) -> some View {
        self.appPrimarySurface(in: shape)
    }
}
