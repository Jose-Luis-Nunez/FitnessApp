import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel

    private let backgroundColor = AppStyle.Color.grayDark
    private let iconSizeWidth: CGFloat = 32
    private let iconSizeHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(backgroundColor)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isSetInProgress && viewModel.timerSeconds > 0 {
                    HStack(spacing: 16) {
                        Image(systemName: "timer")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(AppStyle.Color.white)

                        Text(formatTime(seconds: viewModel.timerSeconds))
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)

                        Text("Aktiver Satz")
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)
                    }
                    .padding(.bottom, 8)
                }

                ForEach(setProgress, id: \.self) { progress in
                    HStack(spacing: 12) {
                        switch progress.status {
                        case .completedDone:
                            icon("checkmark.circle.fill", color: AppStyle.Color.green)
                        case .completedLess:
                            icon("minus.circle.fill", color: AppStyle.Color.yellow)
                        case .completedMore:
                            icon("flame.circle.fill", color: AppStyle.Color.greenGlow)
                        case .notStarted, .inProgress:
                            icon("circle.fill", plain: true)
                        }

                        Text("\(progress.weight) KG")
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)

                        Text("\(progress.currentReps)")
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.green)

                        Text("/ \(exercise.reps)")
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)
                    }
                }
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, viewModel.timerSeconds > 0 ? 24 : 16)
            .padding(.bottom, viewModel.timerSeconds > 0 ? 32 : 16)
        }
        .frame(height: calculateHeight())
        .cornerRadius(AppStyle.CornerRadius.card)
    }

    // MARK: - Helpers

    private func icon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .resizable()
            .frame(width: iconSizeWidth, height: iconSizeHeight)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
    }

    private func icon(_ systemName: String, plain: Bool) -> some View {
        Image(systemName: systemName)
            .resizable()
            .frame(width: iconSizeWidth, height: iconSizeHeight)
            .foregroundColor(.white)
    }

    private func calculateHeight() -> CGFloat {
        let iconHeight = 32.0
        let spacing = 16.0
        let topPadding: CGFloat = viewModel.timerSeconds > 0 ? 24.0 : 16.0
        let bottomPadding: CGFloat = viewModel.timerSeconds > 0 ? 32.0 : 16.0
        let verticalPadding = topPadding + bottomPadding
        let totalIconHeight = CGFloat(setProgress.count) * iconHeight
        let totalSpacing = CGFloat(max(0, setProgress.count - 1)) * spacing
        let timerHeight: CGFloat = viewModel.timerSeconds > 0 ? 24.0 : 0.0
        return totalIconHeight + totalSpacing + verticalPadding + timerHeight
    }

    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
