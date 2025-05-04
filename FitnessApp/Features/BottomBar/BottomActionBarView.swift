import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
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
    
    private let extraOffset: CGFloat = 4
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor
                .frame(height: buttonHeightRegular + 10)
                .frame(maxWidth: UIScreen.main.bounds.width - 32)
                .offset(y: -(buttonHeightRegular / 2 + extraOffset))
            
            HStack(spacing: 24) {
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
                    actionButtonRegular(
                        text: "Less",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.greenLight,
                        fontColor: AppStyle.Color.white,
                        action: onEditLess
                    )
                    
                    actionButtonRegular(
                        text: "Done",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onCompleteSet
                    )
                    
                    actionButtonRegular(
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
            .frame(maxWidth: UIScreen.main.bounds.width - 32, alignment: .center)
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: -(buttonHeightRegular / 2 + extraOffset))
        }
        .frame(height: barHeight + buttonHeightRegular / 2 + extraOffset)
    }
    
    @ViewBuilder
    private func actionButtonRegular(
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
                .frame(width: buttonWidthRegular, height: buttonHeightRegular)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
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
                .frame(width: buttonWidthLarge, height: buttonHeightLarge)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
}
