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
        VStack(spacing: 10) {
            // Zeile 1: Name + Sitz Chip
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
                    size: .regular,
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

            // Zeile 2: Analytics, Sets, Reps, Gewicht
            HStack(alignment: .center, spacing: 20) {
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
                    size: .regular,
                    icon: ChipIcon(image: "sets", color: .white),
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
                    size: .regular,
                    icon: ChipIcon(image: "repeat", color: .white),
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
                    size: .regular,
                    icon: ChipIcon(image: "weight", color: .white),
                    onTap: isEditable ? { onEdit(viewModel.exercise) } : nil
                )
                .frame(minWidth: 60)
                .frame(height: chipHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#726E6A"), lineWidth: 1)
                )
            }

            // Buttons unten rechts (optional)
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
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, AppStyle.Padding.vertical)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
}
