import SwiftUI

struct BottomMenuBarView: View {
    let barHeight: CGFloat
    let onAddExercise: () -> Void
    private let iconOffset: CGFloat = 12

    var body: some View {
        ZStack(alignment: .center) {
            AppStyle.Color.black
                .ignoresSafeArea(edges: .bottom)
                .frame(height: barHeight)

            HStack(spacing: AppStyle.Padding.horizontal) {
                ForEach(["house", "chart.bar", "calendar", "person"], id: \.self) { name in
                    Image(systemName: name)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                        .foregroundColor(AppStyle.Color.green)
                }
                /*
                Button(action: onAddExercise) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: barHeight * 0.6)
                        .foregroundColor(AppStyle.Color.green)
                }
                */
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

    private let buttonWidth: CGFloat = 110
    private let buttonHeight: CGFloat = 50
    private let extraOffset: CGFloat = 10

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.black
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
                .offset(y: -(buttonHeight / 2 + extraOffset))

            HStack(spacing: 12) {
                if viewModel.showStartButton && viewModel.currentSet == 0 {
                    actionButton(title: "Add Exercise",
                                 background: AppStyle.Color.purpleDark,
                                 action: onAddExercise)
                }

                if viewModel.showStartButton {
                    actionButton(title: viewModel.startButtonTitle,
                                 background: AppStyle.Color.green,
                                 action: onStart)
                }

                if viewModel.showSetControls {
                    actionButton(title: "Less", background: AppStyle.Color.purpleDark, action: onEditLess)
                    actionButton(title: "Done", background: AppStyle.Color.green, action: onCompleteSet)
                    actionButton(title: "More", background: AppStyle.Color.purpleDark, action: onEditMore)
                }
                
                if viewModel.showResetProgress {
                    actionButton(title: "Reset", background: AppStyle.Color.purpleGrey, action: onReset)
                }
                
                if viewModel.showFinishButton {
                    actionButton(title: "Beenden", background: AppStyle.Color.purpleGrey, action: onFinish)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: -(buttonHeight / 2 + extraOffset))
        }
        .frame(height: barHeight + buttonHeight / 2 + extraOffset)
    }

    @ViewBuilder
    private func actionButton(title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppStyle.Font.bottomBarButtons)
                .foregroundColor(AppStyle.Color.white)
                .frame(width: buttonWidth, height: buttonHeight)
        }
        .background(background)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
}

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

    var body: some View {
        ZStack(alignment: .bottom) {
            BottomMenuBarView(barHeight: barHeight, onAddExercise: onAddExercise)
            FloatingActionButtonsView(
                viewModel: viewModel,
                onStart: onStart,
                onCompleteSet: onCompleteSet,
                onReset: onReset,
                onEditLess: onEditLess,
                onEditMore: onEditMore,
                onFinish: onFinish,
                onAddExercise: onAddExercise,
                barHeight: barHeight
            )
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
