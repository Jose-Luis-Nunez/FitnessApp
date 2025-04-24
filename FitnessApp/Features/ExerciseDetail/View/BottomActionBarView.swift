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
    
    private let barHeight: CGFloat = 40
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some View {
        ZStack(alignment: .bottom) {
            BottomMenuBarView(
                barHeight: barHeight,
                onAddExercise: onAddExercise,
                backgroundColor: backgroundColor
            )
            
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
        .background(AppStyle.Color.backgroundColor)
    }
}

struct BottomMenuBarView: View {
    let barHeight: CGFloat
    let onAddExercise: () -> Void
    let backgroundColor: Color
    private let iconOffset: CGFloat = 12
    
    var body: some View {
        ZStack(alignment: .center) {
            backgroundColor
                .ignoresSafeArea(edges: .bottom)
                .frame(height: barHeight)
            
            HStack(spacing: AppStyle.Padding.horizontal) {
                ForEach(["house", "chart.bar", "calendar", "person"], id: \.self) { name in
                    Image(systemName: name)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                        .foregroundColor(AppStyle.Color.white)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: iconOffset)
        }
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
    
    private let buttonWidth: CGFloat = 110
    private let buttonHeight: CGFloat = 40
    private let extraOffset: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
                .offset(y: -(buttonHeight / 2 + extraOffset))
            
            HStack(spacing: 12) {
                if viewModel.showStartButton {
                    HStack(spacing: 32) {
                        if viewModel.currentSet == 0 {
                            actionButtonLarge(
                                title: "Add Exercise",
                                background: AppStyle.Color.secondaryButton,
                                fontColor: AppStyle.Color.white,
                                action: onAddExercise
                            )
                        }
                        actionButtonLarge(
                            title: viewModel.startButtonTitle,
                            background: AppStyle.Color.primaryButton,
                            fontColor: AppStyle.Color.white,
                            action: onStart
                        )
                    }
                }
                
                
                if viewModel.showSetControls {
                    actionButtonRegular(title: "Less", background: AppStyle.Color.white, action: onEditLess)
                    actionButtonRegular(title: "Done", background: AppStyle.Color.green, action: onCompleteSet)
                    actionButtonRegular(title: "More", background: AppStyle.Color.white, action: onEditMore)
                }
                
                if viewModel.showResetProgress {
                    actionButtonRegular(title: "Reset", background: AppStyle.Color.white, action: onReset)
                }
                
                if viewModel.showFinishButton {
                    actionButtonRegular(title: "Beenden", background: AppStyle.Color.white, action: onFinish)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: -(buttonHeight / 2 + extraOffset))
        }
        .frame(height: barHeight + buttonHeight / 2 + extraOffset)
    }
    
    @ViewBuilder
    private func actionButtonRegular(title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white)
                .frame(width: buttonWidth, height: buttonHeight)
        }
        .background(background)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
    
    @ViewBuilder
    private func actionButtonLarge(title: String, background: Color,fontColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(fontColor)
                .frame(width: 160, height: 40)
        }
        .background(background)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
}
