import SwiftUI

private enum GlobalConstants {
    static let cardBackgroundColor = AppStyle.Color.exerciseCardBackgroundInactive
}

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool
    
    @State private var isShowingAnalytics = false
    @State private var ratingRowsHeight: CGFloat = 0
    
    var body: some View {
        let latestEntry = analyticsViewModel.loadAnalytics(for: viewModel.exercise.id).max(by: { $0.date < $1.date })
        let setProgress = latestEntry?.setProgress ?? []
        
        CardBackground(backgroundColor: GlobalConstants.cardBackgroundColor, useGlassEffect: true) {
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
                        DoneButton {
                            onReset?(viewModel.exercise)
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                HStack(alignment: .top, spacing: 0) {
                    ExerciseSetSummaryView(setProgress: setProgress)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 4)
                    
                    Divider()
                        .frame(width: 1, height: ratingRowsHeight)
                        .background(Color(hex: "#747055"))
                        .padding(.horizontal, 4)
                    
                    ExerciseRatingSummaryView(
                        goalStars: 3,
                        recordStars: 1,
                        perfectStars: 1,
                        ratingRowsHeight: $ratingRowsHeight
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    
                    Divider()
                        .frame(width: 1, height: ratingRowsHeight)
                        .background(Color(hex: "#747055"))
                        .padding(.horizontal, 4)
                    
                    Button(action: {
                        isShowingAnalytics = true
                    }) {
                        ChipIcon(
                            image: "analyticsEntry",
                            color: AppStyle.Color.greenGlow,
                            size: .extraLarge
                        )
                        .view
                        .frame(width: 60, height: 60)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: viewModel.exercise.isCompleted)
    }
}

extension InactiveCardView {
    
    struct DoneButton: View {
        let onTap: () -> Void

        private enum Constants {
            static let fontSize: CGFloat = 14
            static let horizontalPadding: CGFloat = 20
            static let verticalPadding: CGFloat = 8
            static let strokeColor = AppStyle.Color.greenGlow
            static let backgroundColor = GlobalConstants.cardBackgroundColor
        }

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Text("Done")
                        .foregroundColor(.white)
                        .font(.system(size: Constants.fontSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
                .background(Constants.backgroundColor)
                .overlay(
                    Capsule()
                        .stroke(Constants.strokeColor, lineWidth: 2)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    struct ExerciseSetSummaryView: View {
        let setProgress: [SetProgress]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text("Set").frame(width: 28, alignment: .leading)
                    Text("Reps").frame(width: 36, alignment: .leading)
                    Text("Weight").frame(width: 44, alignment: .leading)
                }
                .foregroundColor(.white)
                .font(.system(size: 11))
                
                ForEach(setProgress.indices, id: \.self) { index in
                    let item = setProgress[index]
                    HStack(spacing: 0) {
                        Text("\(index + 1)").frame(width: 28, alignment: .leading)
                        Text("\(item.currentReps)").frame(width: 36, alignment: .leading)
                        Text("\(item.weight == floor(item.weight) ? "\(Int(item.weight))" : String(item.weight).replacingOccurrences(of: ".", with: ","))").frame(width: 44, alignment: .leading)
                    }
                    .foregroundColor(AppStyle.Color.white)
                    .font(.system(size: 11))
                }
            }
        }
    }
    
    struct ExerciseRatingSummaryView: View {
        let goalStars: Int
        let recordStars: Int
        let perfectStars: Int
        
        @Binding var ratingRowsHeight: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 5) {
                    Spacer()
                    ratingRow(title: "Goal", stars: goalStars, isGoal: true, filledColor: .yellow)
                    ratingRow(title: "Record", stars: recordStars, isGoal: false, filledColor: Color(hex: "#747055"))
                    ratingRow(title: "Perfect", stars: perfectStars, isGoal: false, filledColor: Color(hex: "#747055"))
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                ratingRowsHeight = geo.size.height
                            }
                    }
                )
            }
        }
        
        @ViewBuilder
        private func ratingRow(title: String, stars: Int, isGoal: Bool, filledColor: Color) -> some View {
            HStack(spacing: 6) {
                Circle()
                    .stroke(AppStyle.Color.greenGlow, lineWidth: 1)
                    .frame(width: 13, height: 13)
                    .overlay(
                        Image(systemName: isGoal ? "checkmark" : "")
                            .font(.system(size: 6.5, weight: .medium))
                            .foregroundColor(AppStyle.Color.greenGlow)
                    )
                HStack(spacing: 1) {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 45, alignment: .leading)
                    
                    HStack(spacing: 1) {
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
    }
}
