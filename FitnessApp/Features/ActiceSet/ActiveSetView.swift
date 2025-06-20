import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel

    private let backgroundColor = AppStyle.Color.grayDark
    private let iconSizeWidth: CGFloat = 32
    private let iconSizeHeight: CGFloat = 32
    private let defaultPadding: CGFloat = AppStyle.Padding.horizontal

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(backgroundColor)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 16) {
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
                                        .frame(width: 80, height: 40)
                                        .background(AppStyle.Color.primaryButton)
                                        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
                                }
                                .contentShape(Rectangle())
                                .buttonStyle(PlainButtonStyle())
                                .disabled(progress.status == .completedDone || viewModel.isLastSetCompleted)
                            }
                        }
                        .contentShape(Rectangle())
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
            .padding(.horizontal, defaultPadding)
            .padding(.vertical, defaultPadding)
        }
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
}
