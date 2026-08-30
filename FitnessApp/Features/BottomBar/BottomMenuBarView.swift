import SwiftUI
import FitnessCore
import FitnessUI
import FitnessExercise
import FitnessResources
import FitnessTraining

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

    @State private var miniBarHeight: CGFloat = 0
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
    /// Gap between the training mini bar and the top of the tab capsule row.
    private let miniBarGap: CGFloat = 12
    /// Breathing room above the topmost content on the plate.
    private let barPlateTopPadding: CGFloat = 18
    private let barPlateCornerRadius: CGFloat = 40
    /// How far the plate reaches below the row's layout bottom. The capsule
    /// itself already hangs `bottomOffset` below that, so this is that overhang
    /// plus the margin the plate keeps under it.
    private let barPlateBottomBleed: CGFloat = 45

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

    private var miniBarTargets: [ActiveTrainingTarget] {
        TrainingMiniBar.targets(router: router)
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
            // The mini bar and its plate are drawn as overlay and background so
            // the bar keeps its fixed height: showing or hiding a mini bar must
            // never move the tabs. Both are placed off the measured mini-bar
            // height rather than the layout, which does not know about them.
            let targets = miniBarTargets
            barRow
                .padding(.horizontal, 8)
                .padding(.bottom, bottomOffset)
                .overlay(alignment: .top) { miniBarOverlay(targets) }
                .onPreferenceChange(MiniBarHeightKey.self) { miniBarHeight = $0 }
                .background(alignment: .bottom) {
                    if !targets.isEmpty { barPlate }
                }
        }
    }

    @ViewBuilder
    private func miniBarOverlay(_ targets: [ActiveTrainingTarget]) -> some View {
        if !targets.isEmpty {
            TrainingMiniBarView(targets: targets)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MiniBarHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
                // An offset rather than an alignment guide: a guide set inside
                // this `if` does not reach the overlay's alignment, which put the
                // mini bar straight on top of the tabs. The offset also carries
                // hit testing with it. Hidden until measured so the first frame
                // cannot flash over the tab row.
                .offset(y: -(miniBarHeight + miniBarGap))
                // Hidden *and* inert until measured: at the unmeasured offset the
                // bar sits straight over the tab row, so a tap in that one frame
                // would open the training sheet instead of switching tabs.
                .opacity(miniBarHeight > 0 ? 1 : 0)
                .allowsHitTesting(miniBarHeight > 0)
        }
    }

    /// The capsule keeps its own surface on the plate too. It is partly
    /// transparent and carries only a faint rim, so it reads as a control resting
    /// on the plate rather than a second frame drawn inside it.
    private var barRow: some View {
        HStack(spacing: 6) {
            backButton

            tabBar
                .frame(height: capsuleHeight)
                .clipShape(Capsule())
                .bottomMenuSurface(in: .capsule)

            rightActionButton
        }
    }

    /// Full-bleed glass backdrop behind the mini bar and the tab row. Extended past the
    /// bottom edge so it reads as a surface rising from the screen edge, the way
    /// the Netflix mini player does, instead of a floating card.
    ///
    /// Deliberately contour-free: the plate separates itself from the page by
    /// blur and a faint lift, not by an outline, so it stays a calm material
    /// rather than a stacked card. The accent glow is what keeps a nearly
    /// colourless surface from reading as flat grey.
    ///
    /// The top inset is negative because the plate also has to cover the mini
    /// bar, which the layout does not know about — the measured mini-bar height
    /// keeps that in step with the actual text instead of a guessed constant.
    private var barPlate: some View {
        FloatingChromeSurface.plate(in: barPlateShape)
            .padding(.top, -barPlateTopInset)
            // Pulls the plate in to the bar row's own width. The row already
            // leaves a small margin to the screen, which is what keeps the
            // rounded corners clear of the edges.
            .padding(.horizontal, 8)
            .padding(.bottom, -barPlateBottomBleed)
    }

    /// How far the plate rises above the tab row.
    private var barPlateTopInset: CGFloat { miniBarBlockHeight }

    /// How far the plate has to rise to clear the mini bar as well.
    private var miniBarBlockHeight: CGFloat {
        miniBarHeight + miniBarGap + barPlateTopPadding
    }

    private var barPlateShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: barPlateCornerRadius, style: .continuous)
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
                            .fill(FloatingChromeSurface.selectionFill)
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

    /// The bar's floating controls carry the same glass as the mini bar's plate:
    /// a real background blur with a slight lift and almost no colour of its own.
    ///
    /// No outline. A stroke turns the material into a bordered plate, which is
    /// exactly the flat, framed look the glass is meant to replace — the surfaces
    /// are meant to separate from the page by blur, not by an edge.
    @ViewBuilder
    func bottomMenuSurface<S: InsettableShape>(in shape: S) -> some View {
        self.background {
            FloatingChromeSurface.control(in: shape)
        }
    }
}

// MARK: - Mini Bar Measurement

/// Reports the mini bar's rendered height so the plate can reach exactly over it
/// without the mini bar taking part in layout.
private struct MiniBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
