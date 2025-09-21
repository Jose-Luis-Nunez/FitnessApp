import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onCategoryReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let onResetAllExercises: () -> Void
    // Note: Add/Reset are no longer rendered here; only core training controls remain
    
    // CENTRAL PICKER STATE
    @State private var isShowingEditPicker = false
    @State private var editMode: SetEditingMode = .less

    private let barHeight: CGFloat = 0
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some View {
        if viewModel.shouldShow {
            ZStack(alignment: .bottom) {
                FloatingActionButtonsView(
                    viewModel: viewModel,
                    onStart: onStart,
                    onCompleteSet: onCompleteSet,
                    onQuickDone: onQuickDone,
                    onCompleteAllQuickDone: onCompleteAllQuickDone,
                    onCategoryReset: onCategoryReset,
                    onEditLess: onEditLess,
                    onEditMore: onEditMore,
                    onFinish: onFinish,
                    onAddExercise: onAddExercise,
                    onResetAllExercises: onResetAllExercises,
                    barHeight: barHeight,
                    backgroundColor: backgroundColor
                )
            }
            .background(Color.clear)
            .zIndex(2)
        }
    }
}

struct FloatingActionButtonsView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onCategoryReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let onResetAllExercises: () -> Void
    let barHeight: CGFloat
    let backgroundColor: Color
    // Design constants matching BottomMenuBar  
    private var capsuleHeight: CGFloat { max(48, barHeight * 1.6) }
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth)
    }
    private let selectionHeight: CGFloat = 46
    private var selectionWidth: CGFloat { max(selectionHeight, selectionHeight * 1.8 - 8) } // Breiterer Kreis
    private let selectionFill = Color.white.opacity(0.12)
    
    // FAB-ähnliche Positionierung - schwebt über allem
    private let bottomOffset: CGFloat = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.showQuickDoneBeendenButton {
                // Single large button for "Beenden"
                glassCapsuleButton(
                    text: "Beenden",
                    action: onFinish,
                    style: .finish
                )
            } else if viewModel.showQuickDoneDoneButton {
                // Single large button for "All Done"
                glassCapsuleButton(
                    text: "All Done",
                    action: onCompleteAllQuickDone,
                    style: .allDone
                )
            } else {
                // Main glass bar with training controls
                ZStack {
                    // Glass background matching BottomMenuBar
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

                    HStack(spacing: 0) {
                        if viewModel.showStartButton && (viewModel.currentSet != 0 || viewModel.didJustEditSet) {
                            menuTextItem(
                                text: viewModel.startButtonTitle,
                                action: onStart,
                                style: .start
                            )
                        }

                        if viewModel.showSetControls {
                            menuTextItem(
                                text: "Less",
                                action: onEditLess,
                                style: .control
                            )

                            menuTextItem(
                                text: "Done",
                                action: onCompleteSet,
                                style: .done
                            )

                            menuTextItem(
                                text: "More",
                                action: onEditMore,
                                style: .control
                            )
                            
                            // Quick Done Icon (nur beim ersten Set)
                            if viewModel.currentSet == 0 {
                                menuIconItem(
                                    icon: "quickDoneIcon",
                                    action: onQuickDone,
                                    style: .quickDone
                                )
                            }
                        }

                        if viewModel.showFinishButton {
                            menuTextItem(
                                text: "Beenden",
                                action: onFinish,
                                style: .finish
                            )
                        }
                    }
                    .frame(width: capsuleWidth - 2 * AppStyle.Layout.cardHorizontalPadding)
                }
                .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
            }
        }
        .padding(.horizontal, sideMargin)
        .padding(.bottom, bottomOffset)
        .frame(height: capsuleHeight + 6)
    }

    // Menu item styles
    enum MenuItemStyle {
        case control, done, start, finish, allDone, quickDone
    }
    
    @ViewBuilder
    private func glassCapsuleButton(
        text: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            ZStack {
                // Glass background
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
                
                Text(text)
                    .font(AppStyle.Font.bottomBarButtons)
                    .foregroundColor(AppStyle.Color.white.opacity(0.98))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: capsuleWidth, height: capsuleHeight)
    }

    @ViewBuilder
    private func menuTextItem(
        text: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white.opacity(0.98))
                .frame(maxWidth: .infinity, minHeight: capsuleHeight, maxHeight: capsuleHeight)
                .padding(.horizontal, 4)
                .background(alignment: .center) {
                    if style == .done {
                        RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                            .fill(selectionFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: selectionHeight / 2, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .frame(width: selectionWidth, height: selectionHeight)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func menuIconItem(
        icon: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50) // Maximales Icon
                .foregroundColor(AppStyle.Color.greenLight)
                .frame(width: 44, height: capsuleHeight) // Kompakte feste Breite
                .padding(.leading, 8) // Nur links Padding für nähere Position zu "More"
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}
