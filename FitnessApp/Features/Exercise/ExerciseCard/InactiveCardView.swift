import SwiftUI

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 4)
            
            CardTopSectionView(
                title: viewModel.exercise.name,
                seatText: viewModel.displaySeatText,
                onEdit: onEdit,
                exercise: viewModel.exercise,
                isEditable: isEditable,
                onStart: nil,
                onReset: onReset,
                isActiveSetVisible: false,
                isResetEnabled: isResetEnabled,
                showSeatChip: false
            ).padding(.bottom, 6)
            
         
            
            InactiveCardBottomSectionView(
                viewModel: viewModel,
                analyticsViewModel: analyticsViewModel
            )
            .padding(.top, 0)
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.vertical, 6)
        .frame(maxWidth: UIScreen.main.bounds.width - 2 * AppStyle.Padding.horizontal)
        .background(AppStyle.Color.grayDark3)
        .cornerRadius(AppStyle.CornerRadius.card)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .stroke(AppStyle.Color.green, lineWidth: 1)
        )
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: viewModel.exercise.isCompleted)
    }
}

struct InactiveCardBottomSectionView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Spacer().frame(width: 50)
                headerText("Set", width: 40)
                headerText("Reps", width: 40)
                headerText("Weight", width: 50)
            }
            
            HStack {
                rowLabel("Goal:")
                rowValue("\(viewModel.exercise.sets)", width: 40)
                rowValue("\(viewModel.exercise.reps)", width: 40)
                rowValue("\(viewModel.exercise.weight)", width: 50)
            }
            
            HStack(alignment: .top) {
                labelWithSpacer("You:")
                
                let entries = analyticsViewModel.loadAnalytics(for: viewModel.exercise.id)
                if let lastEntry = entries.max(by: { $0.date < $1.date }) {
                    let (sets, reps, weight) = calculateSummary(from: lastEntry.setProgress)
                    
                    valueWithStar(text: "\(sets)", width: 40)
                    valueWithStar(text: "\(reps)", width: 40)
                    valueWithStar(text: "\(weight)", width: 50)
                } else {
                    valueWithStar(text: "N/A", width: 40, isNA: true)
                    valueWithStar(text: "N/A", width: 40, isNA: true)
                    valueWithStar(text: "N/A", width: 50, isNA: true)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            HStack {
                Spacer()
                Circle()
                    .strokeBorder(AppStyle.Color.green, lineWidth: 5)
                    .background(Circle().fill(AppStyle.Color.grayDark3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("DONE")
                            .foregroundColor(AppStyle.Color.white)
                            .font(AppStyle.Font.doneButton)
                            .bold()
                    )
            }
            .padding(.trailing, 8)
            .padding(.top, 4),
            alignment: .topTrailing
        )
    }
    
    private func headerText(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .multilineTextAlignment(.leading)
            .foregroundColor(AppStyle.Color.white)
            .font(AppStyle.Font.defaultFont)
    }
    
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .frame(width: 50, alignment: .leading)
            .multilineTextAlignment(.leading)
            .foregroundColor(AppStyle.Color.white)
            .font(AppStyle.Font.defaultFont)
    }
    
    private func rowValue(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .multilineTextAlignment(.leading)
            .foregroundColor(AppStyle.Color.white)
            .font(AppStyle.Font.defaultFont)
    }
    
    private func valueWithStar(text: String, width: CGFloat, isNA: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .frame(width: width, alignment: .leading)
                .multilineTextAlignment(.leading)
                .foregroundColor(isNA ? AppStyle.Color.greenGlow : AppStyle.Color.white)
                .font(AppStyle.Font.defaultFont)
            
            Image(systemName: "star.fill")
                .resizable()
                .frame(width: 14, height: 14)
                .frame(width: width, alignment: .leading)
                .padding(.top, 6)
                .foregroundColor(.yellow)
        }
    }
    
    private func labelWithSpacer(_ text: String) -> some View {
        VStack(spacing: 2) {
            rowLabel(text)
            Spacer().frame(height: 20)
        }
    }
    
    private func calculateSummary(from setProgress: [SetProgress]) -> (sets: Int, reps: Int, weight: Int) {
        let sets = setProgress.count
        let reps = setProgress.last?.currentReps ?? 0
        let weight = setProgress.last?.weight ?? 0
        return (sets, reps, weight)
    }
}
