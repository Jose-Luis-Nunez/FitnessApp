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
    
    private let buttonWidthRegular: CGFloat = 110
    private let buttonHeightRegular: CGFloat = 40
    
    private let buttonWidthLarge: CGFloat = 160
    private let buttonHeightLarge: CGFloat = 40
    
    private let extraOffset: CGFloat = 10
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor
                .frame(height: buttonHeightRegular)
                .frame(maxWidth: .infinity)
                .offset(y: -(buttonHeightRegular / 2 + extraOffset))
            
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
                    actionButtonRegular(
                        title: "Less",
                        font: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.greenLight,
                        fontColor: AppStyle.Color.white,
                        action: onEditLess
                    )
                    
                    actionButtonRegular(
                        title: "Done",
                        font: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onCompleteSet
                    )
                    
                    actionButtonRegular(
                        title: "More",
                        font: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.greenLight,
                        fontColor: AppStyle.Color.white,
                        action: onEditMore
                    )
                }
                
                if viewModel.showResetProgress {
                    actionButtonRegular(
                        title: "Reset",
                        font: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onReset
                    )
                }
                
                if viewModel.showFinishButton {
                    actionButtonRegular(
                        title: "Beenden",
                        font: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onFinish
                    )
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: -(buttonHeightRegular / 2 + extraOffset))
        }
        .frame(height: barHeight + buttonHeightRegular / 2 + extraOffset)
    }
    
    @ViewBuilder
    private func actionButtonRegular(
        title: String,
        font: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
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
