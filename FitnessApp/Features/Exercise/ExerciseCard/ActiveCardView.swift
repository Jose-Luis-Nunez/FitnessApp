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
    
    private var formattedWeight: String {
        let weight = viewModel.exercise.weight
        if weight == floor(weight) {
            return "\(Int(weight)) kg"
        } else {
            return "\(weight)".replacingOccurrences(of: ".", with: ",") + " kg"
        }
    }
    
    var body: some View {
        CardBackground(useGlassEffect: true, addPadding: true) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.exercise.name)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                AppChip(
                                    text: "\(viewModel.exercise.sets)x",
                                    fontColor: AppStyle.Color.white,
                                    backgroundColor: Color.clear,
                                    icon: ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow, size: .large),
                                    borderColor: Color(hex: "#2B2B2B")
                                ).frame(height: chipHeight)
                                
                                AppChip(
                                    text: "\(viewModel.exercise.reps)",
                                    fontColor: AppStyle.Color.white,
                                    backgroundColor: Color.clear,
                                    icon: ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green, size: .large),
                                    borderColor: Color(hex: "#2B2B2B")
                                ).frame(height: chipHeight)
                            }
                            
                            Text(formattedWeight)
                                .font(AppStyle.Font.regularChip)
                                .foregroundColor(AppStyle.Color.white)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .frame(height: chipHeight)
                                .frame(width: 166)
                                .background(Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#2B2B2B"), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            isShowingAnalytics = true
                        }) {
                            ChipIcon(
                                image: "analyticsEntry",
                                color: Color(hex:"#077484"),
                                size: .extraLarge
                            )
                            .view
                            .frame(width: 80, height: 68)
                            .background(Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#2B2B2B"), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                
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
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            }
        }
        .padding(.horizontal, 16)
    }
}
