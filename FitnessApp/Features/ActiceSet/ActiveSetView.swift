import SwiftUICore
import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    @Binding var setProgress: [SetProgress]
    @ObservedObject var viewModel: ActiveSetViewModel

    private let backgroundColor = AppStyle.Color.grayDark
    private let iconSize: CGFloat = 32
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
                    ForEach(Array(setProgress.enumerated()), id: \.offset) { index, progress in
                        ActiveSetRowView(
                            index: index,
                            progress: progress,
                            exercise: exercise,
                            activeSetIndex: viewModel.activeSetIndex,
                            iconSize: iconSize
                        )
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
            .frame(width: iconSize, height: iconSize)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
    }
}

private struct ActiveSetRowView: View {
    let index: Int
    let progress: SetProgress
    let exercise: Exercise
    let activeSetIndex: Int
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // Linker Kreis
            ZStack {
                Circle()
                    .fill(AppStyle.Color.black)
                    .frame(width: iconSize, height: iconSize)

                if index == activeSetIndex {
                    Circle()
                        .stroke(AppStyle.Color.greenGlow, lineWidth: 2)
                        .frame(width: iconSize, height: iconSize)
                }

                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppStyle.Color.white)
            }

            Text("\(progress.weight) KG")
                .font(AppStyle.Font.largeChip)
                .foregroundColor(AppStyle.Color.white)

            Spacer()

            HStack(spacing: 4) {
                Text("\(exercise.reps)")
                    .font(AppStyle.Font.largeChip)
                    .foregroundColor(AppStyle.Color.white)

                Text("/")
                    .font(AppStyle.Font.largeChip)
                    .foregroundColor(AppStyle.Color.white)

                if progress.status != .notStarted && progress.status != .inProgress {
                    Text("\(progress.currentReps)")
                        .font(AppStyle.Font.largeChip)
                        .foregroundColor(AppStyle.Color.green)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppStyle.Color.green)
                }
                Spacer()
            }
        }
    }
}
