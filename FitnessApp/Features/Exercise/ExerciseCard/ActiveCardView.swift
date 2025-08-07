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
    private let chipHeight: CGFloat = 32
    
    var body: some View {
        CardBackground {
            HStack(alignment: .center, spacing: 8) {
                // Bereich A: Titel + Analytics Icon oben, 3 Chips unten
                VStack(spacing: 6) {
                    // Zeile 1: Titel + Analytics Icon
                    HStack(alignment: .center) {
                        Text(viewModel.exercise.name)
                            .font(AppStyle.Font.cardHeadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            isShowingAnalytics = true
                        }) {
                            ChipIcon(
                                image: "analyticsEntry",
                                color: AppStyle.Color.white,
                                size: .extraLarge
                            )
                            .view
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Zeile 2: 3 Chips
                    HStack(spacing: 6) {
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
                            text: "\(viewModel.exercise.weight == floor(viewModel.exercise.weight) ? "\(Int(viewModel.exercise.weight))" : String(viewModel.exercise.weight).replacingOccurrences(of: ".", with: ",")) kg",
                            fontColor: AppStyle.Color.white,
                            backgroundColor: AppStyle.Color.chipsBackground,
                            size: .regular
                        ).frame(height: chipHeight)
                    }
                }
                
                // Bereich B: Icon mit gleicher Breite wie Active Set View
                VStack {
                    ZStack {
                        Circle()
                            .fill(AppStyle.Color.greenBlack)
                            .frame(width: 110 * 0.9, height: 110 * 0.9)
                            .blur(radius: 15)
                            .opacity(0.5)
                        
                        Image(viewModel.exercise.displayIconName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 110, height: 110, alignment: viewModel.exercise.iconAlignment)
                            .clipped()
                    }
                }
                .frame(width: 80)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 100)
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
}
