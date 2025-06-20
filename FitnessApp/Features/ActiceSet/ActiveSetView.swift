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
                .contentShape(Rectangle()) // Verhindere Touch-Propagation auf den Hintergrund

            VStack(alignment: .leading, spacing: 16) {
                // Timer Row
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

                // Quick Done Mode
                if viewModel.quickDoneModeActive {
                    ForEach(setProgress.indices, id: \.self) { index in
                        let progress = setProgress[index]
                        HStack(spacing: 12) {
                            if progress.status == .completedDone {
                                icon("checkmark.circle.fill", color: AppStyle.Color.green)
                                Text("\(progress.weight) KG")
                                    .font(AppStyle.Font.largeChip)
                                    .foregroundColor(AppStyle.Color.white)
                                Text("\(progress.currentReps)")
                                    .font(AppStyle.Font.largeChip)
                                    .foregroundColor(AppStyle.Color.green)
                                Text("/ \(progress.currentReps)")
                                    .font(AppStyle.Font.largeChip)
                                    .foregroundColor(AppStyle.Color.white)
                            } else {
                                Button(action: {
                                    print("Marking set \(index) as done at time \(Date()) with trigger source: Button \(index)")
                                    viewModel.pendingSetIndex = index
                                }) {
                                    Text("Done")
                                        .font(AppStyle.Font.bottomBarButtons)
                                        .foregroundColor(AppStyle.Color.white)
                                        .frame(width: 80, height: 40) // Explizite Größe
                                        .background(AppStyle.Color.primaryButton)
                                        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
                                }
                                .contentShape(Rectangle()) // Begrenze die Klickfläche strikt auf den Button
                                .buttonStyle(PlainButtonStyle()) // Verhindere Standard-Propagation
                                .disabled(progress.status == .completedDone || viewModel.isLastSetCompleted)
                            }
                        }
                        .contentShape(Rectangle()) // Begrenze die Klickfläche der HStack
                    }
                }

                // Normal Mode
                else {
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
            }
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, viewModel.timerSeconds > 0 ? 24 : 16)
            .padding(.bottom, viewModel.timerSeconds > 0 ? 32 : 16)
        }
        .frame(height: calculateHeight())
        .cornerRadius(AppStyle.CornerRadius.card)
        .onChange(of: viewModel.pendingSetIndex) { index in
            if let index = index {
                print("Processing change for index \(index) at time \(Date()) from onChange")
                viewModel.processQuickDone(at: index)
                viewModel.pendingSetIndex = nil
            }
        }
    }

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
        let buttonHeight = 40.0
        let spacing = 16.0
        let topPadding: CGFloat = viewModel.timerSeconds > 0 ? 24.0 : 16.0
        let bottomPadding: CGFloat = viewModel.timerSeconds > 0 ? 32.0 : 16.0
        let verticalPadding = topPadding + bottomPadding

        let rowsCount: Int = viewModel.quickDoneModeActive
            ? setProgress.count
            : setProgress.count

        let totalRowHeight = CGFloat(rowsCount) * (viewModel.quickDoneModeActive ? buttonHeight : iconHeight)
        let totalSpacing = CGFloat(max(0, rowsCount - 1)) * spacing

        let timerHeight: CGFloat = viewModel.timerSeconds > 0 ? 24.0 : 0.0

        return totalRowHeight + totalSpacing + verticalPadding + timerHeight
    }

    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
