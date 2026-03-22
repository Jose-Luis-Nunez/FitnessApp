import SwiftUI

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?

    @State private var isShowingAnalytics = false

    private var formattedWeight: String {
        let weight = viewModel.exercise.weight
        if weight == floor(weight) {
            return "\(Int(weight)) kg"
        } else {
            return "\(weight)".replacingOccurrences(of: ".", with: ",") + " kg"
        }
    }

    var body: some View {
        CardBackground(backgroundColor: AppStyle.Color.exerciseCardBackground, useGlassEffect: true, addPadding: false) {
            HStack(spacing: 10) {
                categoryIconView
                titleSection
                playButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                Group {
                    if #available(iOS 26.0, *) {
                        Rectangle()
                            .fill(Color(hex: "#27262a"))
                            .frame(width: 66)
                            .glassEffect(in: .rect)
                    } else {
                        Color(hex: "#27262a")
                            .frame(width: 66)
                    }
                }
            }
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }

    private var categoryIconView: some View {
        Image(viewModel.exercise.category.defaultIconName)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50, alignment: viewModel.exercise.category.iconAlignment)
            .clipped()
            .foregroundColor(AppStyle.Color.white)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.exercise.name)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    if isEditable { onEdit(viewModel.exercise) }
                }

            HStack(spacing: 10) {
                Text(formattedWeight)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))

                Text("·")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))

                Image("chairSettings")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white.opacity(0.7))

                if let seatSetting = viewModel.exercise.seatSetting {
                    Text(seatSetting)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text("·")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))

                Button(action: { isShowingAnalytics = true }) {
                    Image("analyticsEntry")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var playButton: some View {
        if let onStart = onStart, !viewModel.exercise.isCompleted {
            Button(action: { onStart(viewModel.exercise) }) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.greenGlow)
                        .frame(width: 36, height: 36)

                    Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(AppStyle.Color.exerciseCardBackground)
                }
            }
            .accessibilityIdentifier("id_button_start_exercise")
            .buttonStyle(.plain)
        }
    }
}
