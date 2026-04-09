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
    private var capsuleHeight: CGFloat { max(48, barHeight * 1.6) }
    private let sideMargin: CGFloat = AppStyle.Layout.cardHorizontalPadding
    private var capsuleWidth: CGFloat {
        let defaultWidth = UIScreen.main.bounds.width - (2 * sideMargin)
        return max(240, defaultWidth - 50)
    }
    private let selectionHeight: CGFloat = 46
    private var selectionWidth: CGFloat { max(selectionHeight, selectionHeight * 2.2 - 6) }
    private let selectionFill = Color.white.opacity(0.12)
    private let bottomOffset: CGFloat = 16

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.showQuickDoneBeendenButton {
                glassCapsuleButton(
                    text: "Beenden",
                    action: onFinish,
                    style: .finish
                )
            } else if viewModel.showQuickDoneDoneButton {
                glassCapsuleButton(
                    text: "All Done",
                    action: onCompleteAllQuickDone,
                    style: .allDone
                )
            } else {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous)
                            .fill(Color.clear)
                            .glassEffect()
                        
                        HStack(spacing: 18) {
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
                            }

                            if viewModel.showFinishButton {
                                menuTextItem(
                                    text: "Beenden",
                                    action: onFinish,
                                    style: .finish
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: capsuleHeight)
                    .clipShape(RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous))
                    
                    if viewModel.showSetControls && viewModel.currentSet == 0 {
                        menuIconItem(
                            icon: "quickDoneIcon",
                            action: onQuickDone,
                            style: .quickDone
                        )
                    }
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.bottom, bottomOffset)
        .frame(height: capsuleHeight + 6)
    }

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
                RoundedRectangle(cornerRadius: capsuleHeight / 2, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: capsuleWidth, height: capsuleHeight)
                    .glassEffect()
                
                Text(text)
                    .font(AppStyle.Font.bottomBarButtons)
                    .foregroundColor(AppStyle.Color.white.opacity(0.98))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: capsuleWidth, height: capsuleHeight)
        .accessibilityIdentifier(accessibilityID(for: style, text: text))
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
                .padding(.horizontal, 2)
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
        .accessibilityIdentifier(accessibilityID(for: style, text: text))
    }
    
    @ViewBuilder
    private func menuIconItem(
        icon: String,
        action: @escaping () -> Void,
        style: MenuItemStyle
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .glassEffect()
                    .overlay(
                    Circle().stroke(AppStyle.Color.white.opacity(0.10), lineWidth: 1)
                )
                
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .frame(width: 44, height: 44) // EXAKT wie BottomMenuBar buttons
        .contentShape(Circle())
        .buttonStyle(.plain)
    }

    private func accessibilityID(for style: MenuItemStyle, text: String) -> String {
        switch style {
        case .done:      return TrainingIDs.doneButton
        case .finish:    return TrainingIDs.finishButton
        case .start:     return TrainingIDs.startButton
        case .allDone:   return TrainingIDs.allDoneButton
        case .control:   return TrainingIDs.controlButton(text)
        case .quickDone: return TrainingIDs.quickDoneButton
        }
    }
}
