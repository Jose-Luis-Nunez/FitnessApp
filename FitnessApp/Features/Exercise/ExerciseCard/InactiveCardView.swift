import SwiftUI

private enum GlobalConstants {
    static let cardBackgroundColor = AppStyle.Color.exerciseCardBackground
}

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool
    
    @State private var isShowingAnalytics = false
    
    var body: some View {
        let latestEntry = analyticsViewModel.loadAnalytics(for: viewModel.exercise.id).max(by: { $0.date < $1.date })
        let setProgress = latestEntry?.setProgress ?? []
        
        CardBackground {
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.exercise.name)
                        .font(AppStyle.Font.cardHeadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("id_label_exercise_name")
                        .onTapGesture {
                            if isEditable { onEdit(viewModel.exercise) }
                        }
                    
                    if isResetEnabled {
                        AbgeschlossenChip {
                            onReset?(viewModel.exercise)
                        }
                        .padding(.horizontal, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(alignment: .top, spacing: 8) {
                    ExerciseSetSummaryView(setProgress: setProgress)
                        .padding(.trailing, 3)
                    
                    Divider()
                        .frame(height: CGFloat((setProgress.count + 1) * 16))
                        .background(Color(hex: "#747055"))
                    
                    ExerciseRatingSummaryView(
                        goalStars: 3,
                        recordStars: 1,
                        perfectStars: 1
                    )
                    .padding(.horizontal, 4)
                    
                    Divider()
                        .frame(height: CGFloat((setProgress.count + 1) * 16))
                        .background(Color(hex: "#747055"))
                    
                    Button(action: {
                        isShowingAnalytics = true
                    }) {
                        ChipIcon(
                            image: "analyticsEntry",
                            color: AppStyle.Color.greenGlow,
                            size: .extraLarge
                        )
                        .view
                        .frame(maxWidth: 60, maxHeight: 60)
                        .clipped()
                        .padding(.leading, 4)
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity) // Begrenzt die gesamte VStack
            }
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
            }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: viewModel.exercise.isCompleted)
        }
    }
    
    struct AbgeschlossenChip: View {
        let onTap: () -> Void
        
        private enum Constants {
            static let fontSize: CGFloat = 12
            static let horizontalPadding: CGFloat = 8
            static let verticalPadding: CGFloat = 8
            static let cornerRadius: CGFloat = AppStyle.CornerRadius.card
            static let strokeColor = AppStyle.Color.greenGlow
            static let backgroundColor = GlobalConstants.cardBackgroundColor.opacity(0.95)
        }
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 2) {
                    ZStack {
                        Image("batchCompleted")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .foregroundColor(AppStyle.Color.greenGlow)
                            .scaleEffect(1.4)
                    }
                    
                    Text("Done")
                        .foregroundColor(.white)
                        .font(.system(size: Constants.fontSize, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
                .background(Constants.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                        .stroke(Constants.strokeColor, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .buttonStyle(.plain)
        }
    }
    
    struct ExerciseSetSummaryView: View {
        let setProgress: [SetProgress]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("Set").frame(width: 28, alignment: .leading)
                    Text("Reps").frame(width: 36, alignment: .leading)
                    Text("Weight").frame(width: 44, alignment: .leading)
                }
                .foregroundColor(.white)
                .font(AppStyle.Font.defaultFont)
                
                ForEach(setProgress.indices, id: \.self) { index in
                    let item = setProgress[index]
                    HStack(spacing: 0) {
                        Text("\(index + 1)").frame(width: 28, alignment: .leading)
                        Text("\(item.currentReps)").frame(width: 36, alignment: .leading)
                        Text("\(item.weight)").frame(width: 44, alignment: .leading)
                    }
                    .foregroundColor(.white)
                    .font(AppStyle.Font.defaultFont)
                }
            }
        }
    }
    
    struct ExerciseRatingSummaryView: View {
        let goalStars: Int
        let recordStars: Int
        let perfectStars: Int
        
        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack { Spacer() }
                    .frame(height: 10)
                ratingRow(title: "Goal", stars: goalStars, isGoal: true, filledColor: .yellow)
                ratingRow(title: "Record", stars: recordStars, isGoal: false, filledColor: Color(hex: "#747055"))
                ratingRow(title: "Perfect", stars: perfectStars, isGoal: false, filledColor: Color(hex: "#747055"))
            }
        }
        
        @ViewBuilder
        private func ratingRow(title: String, stars: Int, isGoal: Bool, filledColor: Color) -> some View {
            HStack(spacing: 6) {
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: isGoal ? "checkmark" : "")
                            .font(.system(size: 6.5, weight: .medium))
                            .foregroundColor(AppStyle.Color.greenGlow)
                    )
                
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 45, alignment: .leading)
                
                HStack(spacing: 2) {
                    ForEach(0..<stars, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(filledColor)
                    }
                }
            }
        }
    }
    
    struct CardBackground<Content: View>: View {
        let content: Content
        let cornerRadius: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        
        let backgroundColor = GlobalConstants.cardBackgroundColor
        
        init(
            cornerRadius: CGFloat = AppStyle.CornerRadius.card,
            horizontalPadding: CGFloat = AppStyle.Padding.horizontal,
            verticalPadding: CGFloat = AppStyle.Padding.vertical,
            @ViewBuilder content: () -> Content
        ) {
            self.cornerRadius = cornerRadius
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
            self.content = content()
        }
        
        var body: some View {
            content
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .containerShape(RoundedRectangle(cornerRadius: cornerRadius))
                .clipped()
            
        }
    }
}
