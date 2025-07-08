import SwiftUI

struct ActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onStart: ((Exercise) -> Void)?
    let onReset: ((Exercise) -> Void)?
    let isActiveSetVisible: Bool
    let isResetEnabled: Bool

    @State private var isShowingAnalytics = false

    private let maxChipWidth: CGFloat = 88
    private let chipHeight: CGFloat = 32
    private let chipSpacing: CGFloat = 6

    private var totalChipHeight: CGFloat {
        chipHeight
    }

    var body: some View {
        CardBackground {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    Text(viewModel.exercise.name)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            if isEditable {
                                onEdit(viewModel.exercise)
                            }
                        }

                    AppChip(
                        text: viewModel.exercise.seatSetting ?? L10n.seatChipDefaultvalue,
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.chipsBackground,
                        size: AppChipSize.regular,
                        icon: ChipIcon(image: "chairSettings", color: .white),
                        onTap: isEditable ? { onEdit(viewModel.exercise) } : nil
                    )
                    .frame(minWidth: 60)
                    .frame(height: chipHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#726E6A"), lineWidth: 1)
                    )
                }

                HStack(alignment: .center, spacing: 10) {
                    Button(action: { isShowingAnalytics = true }) {
                        ChipIcon(
                            image: "analyticsEntry",
                            color: AppStyle.Color.greenGlow,
                            size: .extraLarge
                        )
                        .view
                        .frame(width: 36, height: totalChipHeight)
                    }
                    .buttonStyle(.plain)

                    AppChip(
                        text: "\(viewModel.exercise.sets)x",
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.exerciseCardBackground,
                        size: AppChipSize.regular,
                        icon: ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow),
                        onTap: isEditable ? { onEdit(viewModel.exercise) } : nil
                    )
                    .frame(minWidth: 60)
                    .frame(height: chipHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#726E6A"), lineWidth: 1)
                    )

                    AppChip(
                        text: "\(viewModel.exercise.reps)",
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.exerciseCardBackground,
                        size: AppChipSize.regular,
                        icon: ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green),
                        onTap: isEditable ? { onEdit(viewModel.exercise) } : nil
                    )
                    .frame(minWidth: 60)
                    .frame(height: chipHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#726E6A"), lineWidth: 1)
                    )

                    AppChip(
                        text: "\(viewModel.exercise.weight) kg",
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.green,
                        size: AppChipSize.regular,
                        onTap: isEditable ? { onEdit(viewModel.exercise) } : nil,
                    )
                    .frame(minWidth: 60)
                    .frame(height: chipHeight)
                }

                HStack {
                    Spacer()
                    if isResetEnabled, let onReset = onReset {
                        Button(action: {
                            onReset(viewModel.exercise)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 28)
                                Image(systemName: "eject.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("id_button_reset_exercise")
                    }

                    if let onStart = onStart, !viewModel.exercise.isCompleted, !isActiveSetVisible {
                        Button(action: {
                            onStart(viewModel.exercise)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(AppStyle.Color.green)
                                    .frame(width: 28)
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 10, height: 10)
                                    .foregroundColor(.white)
                                    .offset(x: 1.2, y: -1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("id_button_start_exercise")
                    }
                }
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
}
