import SwiftUI

struct BottomMenuBarView: View {
    let barHeight: CGFloat

    var body: some View {
        ZStack(alignment: .center) {
            AppStyle.Color.purpleDark
                .ignoresSafeArea(edges: .bottom)
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)

            HStack(spacing: AppStyle.Padding.horizontal) {
                Image(systemName: "house")
                    .resizable()
                    .scaledToFit()
                    .frame(width: barHeight * 1.8, height: barHeight * 0.5)
                    .foregroundColor(AppStyle.Color.green)

                Image(systemName: "chart.bar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: barHeight * 1.8, height: barHeight * 0.5)
                    .foregroundColor(AppStyle.Color.green)

                Image(systemName: "calendar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: barHeight * 1.8, height: barHeight * 0.5)
                    .foregroundColor(AppStyle.Color.green)

                Image(systemName: "person")
                    .resizable()
                    .scaledToFit()
                    .frame(width: barHeight * 1.8, height: barHeight * 0.5)
                    .foregroundColor(AppStyle.Color.green)
            }
            .frame(maxWidth: .infinity)
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
                if viewModel.showStartButton {
                    actionButton(title: viewModel.startButtonTitle,
                                 background: AppStyle.Color.green,
                                 action: onStart)
                }
                if viewModel.showSetControls {
                    actionButton(title: "Less",   background: AppStyle.Color.purpleGrey, action: onEditLess)
                    actionButton(title: "Done",   background: AppStyle.Color.green,      action: onCompleteSet)
                    actionButton(title: "More",   background: AppStyle.Color.purpleGrey, action: onEditMore)
                }
                if viewModel.showResetProgress {
                    actionButton(title: "Reset",  background: AppStyle.Color.purpleGrey, action: onReset)
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

    private let barHeight: CGFloat = 40

    var body: some View {
        ZStack(alignment: .bottom) {
            BottomMenuBarView(barHeight: barHeight)
            FloatingActionButtonsView(
                viewModel: viewModel,
                onStart: onStart,
                onCompleteSet: onCompleteSet,
                onReset: onReset,
                onEditLess: onEditLess,
                onEditMore: onEditMore,
                onFinish: onFinish,
                barHeight: barHeight
            )
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
