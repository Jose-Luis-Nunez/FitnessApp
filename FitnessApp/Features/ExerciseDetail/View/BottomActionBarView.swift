import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    content
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .frame(width: geo.size.width)
                .background(
                    Rectangle()
                        .fill(AppStyle.Color.purpleDark)
                        .edgesIgnoringSafeArea(.bottom) // deckt Home-Indikator ab
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                )
            }
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.showSetControls {
            ButtonGroupSetControls(onEditLess: onEditLess, onDone: onCompleteSet, onEditMore: onEditMore)
        } else if viewModel.showStartButton {
            ActionButton(title: viewModel.startTitle, action: onStart, wide: true)
        } else if viewModel.showResetProgress {
            ActionButton(title: L10n.resetProgress, action: onReset, wide: true)
        }
    }
}

private struct ButtonGroupSetControls: View {
    let onEditLess: () -> Void
    let onDone: () -> Void
    let onEditMore: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ActionButton(title: L10n.less, action: onEditLess)
            ActionButton(title: L10n.done, action: onDone)
            ActionButton(title: L10n.more, action: onEditMore)
        }
    }
}

private struct ActionButton: View {
    let title: String
    let action: () -> Void
    let wide: Bool

    init(title: String, action: @escaping () -> Void, wide: Bool = false) {
        self.title = title
        self.action = action
        self.wide = wide
    }

    var body: some View {
        Button(title, action: action)
            .fontWeight(.semibold)
            .foregroundColor(AppStyle.Color.white)
            .padding(.horizontal, wide ? 32 : 20)
            .padding(.vertical, 12)
            .background(AppStyle.Color.purpleGrey)
            .clipShape(Capsule())
    }
}

extension L10n {
    static let resetProgress = "Reset Progress"
    static let less = "Less"
    static let more = "More"
    static let done = "Done!"
}
