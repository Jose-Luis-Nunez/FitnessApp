import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void

    private let buttonWidth: CGFloat = 110
    private let buttonHeight: CGFloat = 50
    private let barHeight: CGFloat = 40

    var body: some View {
        ZStack(alignment: .bottom) {
            AppStyle.Color.purpleDark
                .ignoresSafeArea(edges: .bottom)
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                if viewModel.showStartButton {
                    actionButton(
                        title: viewModel.startButtonTitle,
                        background: AppStyle.Color.green,
                        action: onStart
                    )
                }
                if viewModel.showSetControls {
                    actionButton(title: "Less",     background: AppStyle.Color.purpleGrey, action: onEditLess)
                    actionButton(title: "Done",     background: AppStyle.Color.green,      action: onCompleteSet)
                    actionButton(title: "More",     background: AppStyle.Color.purpleGrey, action: onEditMore)
                }
                if viewModel.showResetProgress {
                    actionButton(title: "Reset",    background: AppStyle.Color.purpleGrey, action: onReset)
                }
                if viewModel.showFinishButton {
                    actionButton(title: "Beenden", background: AppStyle.Color.purpleGrey, action: onFinish)
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .offset(y: -(barHeight / 2 + buttonHeight / 2 + 10))
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
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
        .cornerRadius(AppStyle.CornerRadius.card)
    }
}
