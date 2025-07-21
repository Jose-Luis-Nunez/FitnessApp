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
    
    private let chipHeight: CGFloat = 32
    
    var body: some View {
        CardBackground {
            GeometryReader { geo in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.exercise.name)
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(.white)
                            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 10) {
                            AppChip(
                                text: "\(viewModel.exercise.sets)x",
                                fontColor: AppStyle.Color.white,
                                backgroundColor: AppStyle.Color.chipsBackground,
                                icon: ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow)
                            ).frame(height: chipHeight)
                            
                            AppChip(
                                text: "\(viewModel.exercise.reps)",
                                fontColor: AppStyle.Color.white,
                                backgroundColor: AppStyle.Color.chipsBackground,
                                icon: ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green)
                            ).frame(height: chipHeight)
                            
                            AppChip(
                                text: "\(viewModel.exercise.weight) kg",
                                fontColor: AppStyle.Color.white,
                                backgroundColor: AppStyle.Color.green,
                                size: .regular
                            ).frame(height: chipHeight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    
                    let iconSize = min(max(min(geo.size.width, 500) * 0.30, 70), 120)
                    
                    VStack {
                        Image(viewModel.exercise.displayIconName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: iconSize, height: iconSize, alignment: viewModel.exercise.iconAlignment)
                            .clipped()
                    }
                    .frame(width: iconSize)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 100)
        }
        .padding(.horizontal, AppStyle.Padding.card)
    }
}
