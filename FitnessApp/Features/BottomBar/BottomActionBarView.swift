import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    
    private let barHeight: CGFloat = 0
    private let backgroundColor = AppStyle.Color.backgroundColor
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            FloatingActionButtonsView(
                viewModel: viewModel,
                onStart: onStart,
                onCompleteSet: onCompleteSet,
                onQuickDone: onQuickDone,
                onCompleteAllQuickDone: onCompleteAllQuickDone,
                onReset: onReset,
                onEditLess: onEditLess,
                onEditMore: onEditMore,
                onFinish: onFinish,
                onAddExercise: onAddExercise,
                barHeight: barHeight,
                backgroundColor: backgroundColor
            )
        }
        .background(backgroundColor)
    }
}

struct FloatingActionButtonsView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let barHeight: CGFloat
    let backgroundColor: Color
    
    private let buttonWidthRegular: CGFloat = 110
    private let buttonHeightRegular: CGFloat = 40
    
    private let buttonWidthLarge: CGFloat = 160
    private let buttonHeightLarge: CGFloat = 40
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor
                .frame(height: buttonHeightRegular * 2 + 32)
                .frame(maxWidth: UIScreen.main.bounds.width - 32)
            
            VStack(spacing: 8) {
                
                if viewModel.showQuickDoneBeendenButton {
                    actionButtonExtraLarge(
                        text: "Beenden",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onFinish
                    )
                } else if viewModel.showQuickDoneDoneButton {
                    actionButtonExtraLarge(
                        text: "All Done",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.primaryButton,
                        fontColor: AppStyle.Color.white,
                        action: onCompleteAllQuickDone
                    )
                }
                else {
                    if viewModel.showSetControls && viewModel.currentSet == 0 {
                        actionButtonExtraLarge(
                            text: "Quick done",
                            textFont: AppStyle.Font.bottomBarButtons,
                            backgroundColor: AppStyle.Color.grayDark,
                            fontColor: AppStyle.Color.white,
                            action: onQuickDone
                        )
                    }
                    
                    HStack(spacing: 12) {
                        if viewModel.showAddExerciseButton {
                            actionButtonLarge(
                                text: "Add Exercise",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.secondaryButton,
                                fontColor: AppStyle.Color.white,
                                action: onAddExercise
                            )
                        }
                        
                        if viewModel.showStartButton {
                            actionButtonLarge(
                                text: viewModel.startButtonTitle,
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.primaryButton,
                                fontColor: AppStyle.Color.white,
                                action: onStart
                            )
                        }
                        
                        if viewModel.showSetControls {
                            actionButtonSmall(
                                text: "Less",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.greenLight,
                                fontColor: AppStyle.Color.white,
                                action: onEditLess
                            )
                            
                            actionButtonLarge(
                                text: "Done",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: onCompleteSet
                            )
                            
                            actionButtonSmall(
                                text: "More",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.greenLight,
                                fontColor: AppStyle.Color.white,
                                action: onEditMore
                            )
                        }
                        
                        if viewModel.showResetProgress {
                            actionButtonLarge(
                                text: "Reset",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: onReset
                            )
                        }
                        
                        if viewModel.showFinishButton {
                            actionButtonLarge(
                                text: "Beenden",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: onFinish
                            )
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Layout.cardHorizontalPadding, alignment: .center)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(height: buttonHeightRegular * 2 + 32)
    }
    
    @ViewBuilder
    private func actionButtonLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: buttonHeightLarge, maxHeight: buttonHeightLarge)
                .padding(.horizontal, 12)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    
    @ViewBuilder
    private func actionButtonSmall(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(width: buttonWidthRegular / 1.5, height: buttonHeightRegular)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
    
    @ViewBuilder
    private func actionButtonExtraLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(
                    maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Layout.cardHorizontalPadding,
                    minHeight: buttonHeightLarge,
                    maxHeight: buttonHeightLarge
                )
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
}
