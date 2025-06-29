import SwiftUI

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?

    @State private var isShowingAnalytics = false

    private let maxChipWidth: CGFloat = 88
    private let chipHeight: CGFloat = 32
    private let chipSpacing: CGFloat = 6

    private var totalChipHeight: CGFloat {
        chipHeight * 2 + chipSpacing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
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

            HStack(alignment: .center, spacing: 28) {
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

                VStack(spacing: chipSpacing) {
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

                    AppChip(
                        text: "\(viewModel.exercise.weight) kg",
                        fontColor: AppStyle.Color.white,
                        backgroundColor: AppStyle.Color.chipsBackground,
                        size: .regular,
                        onTap: isEditable ? { onEdit(viewModel.exercise) } : nil
                    )
                    .frame(minWidth: 60)
                    .frame(height: chipHeight)
                }
            }

            if let onStart = onStart, !viewModel.exercise.isCompleted {
                Button(action: { onStart(viewModel.exercise) }) {
                    ZStack {
                        Circle()
                            .fill(AppStyle.Color.green)
                            .frame(width: 36, height: 36)

                        Image(systemName: "play.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                            .offset(x: 1, y: -1)
                    }
                }
                .accessibilityIdentifier("id_button_start_exercise")
                .buttonStyle(.plain)
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
