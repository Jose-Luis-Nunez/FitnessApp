import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    let setProgress: [SetProgress]
    let timerSeconds: Int
    
    private let backgroundColor = AppStyle.Color.grayDark
    private let iconSizeWidth: CGFloat = 32
    private let iconSizeHeight: CGFloat = 32
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(backgroundColor)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 16) {
                if timerSeconds > 0 {
                    HStack(spacing: 16) {
                        Image(systemName: "timer")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(AppStyle.Color.white)
                        
                        Text(formatTime(seconds: timerSeconds))
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)
                        
                        Text("Aktiver Satz")
                            .font(AppStyle.Font.largeChip)
                            .foregroundColor(AppStyle.Color.white)
                    }
                    .padding(.bottom, 8)
                }
                
                ForEach(0..<sets, id: \.self) { index in
                    HStack(spacing: 12) {
                        if index < setProgress.count {
                            switch setProgress[index].action {
                            case .done:
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(AppStyle.Color.white, AppStyle.Color.green)
                            case .less:
                                Image(systemName: "minus.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(AppStyle.Color.white, AppStyle.Color.green)
                            case .more:
                                Image(systemName: "flame.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(AppStyle.Color.white, AppStyle.Color.green)
                            case .none:
                                Image(systemName: "circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .foregroundColor(AppStyle.Color.white)
                            }
                        } else {
                            Image(systemName: "bolt.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: iconSizeWidth * 0.7, height: iconSizeHeight * 0.7)
                                .padding(6)
                                .clipShape(Circle())
                                .foregroundColor(AppStyle.Color.yellow)
                        }
                        
                        if index < setProgress.count {
                            Text("\(setProgress[index].weight) KG")
                                .font(AppStyle.Font.largeChip)
                                .foregroundColor(AppStyle.Color.white)
                        }
                        
                        if index < setProgress.count {
                            Text("\(setProgress[index].currentReps)")
                                .font(AppStyle.Font.largeChip)
                                .foregroundColor(AppStyle.Color.green)
                        }
                        
                        if index < setProgress.count {
                            Text("/  \(exercise.reps)")
                                .font(AppStyle.Font.largeChip)
                                .foregroundColor(AppStyle.Color.white)
                        }
                        
                    }
                }
            }
            
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, timerSeconds > 0 ? 24 : 16)
            .padding(.bottom, timerSeconds > 0 ? 32 : 16)
        }
        .frame(height: calculateHeight())
        .cornerRadius(AppStyle.CornerRadius.card)
    }
    
    private func calculateHeight() -> CGFloat {
        let iconHeight = 32.0
        let spacing = 16.0
        let topPadding: CGFloat = timerSeconds > 0 ? 24.0 : 16.0
        let bottomPadding: CGFloat = timerSeconds > 0 ? 32.0 : 16.0
        let verticalPadding = topPadding + bottomPadding
        let totalIconHeight = CGFloat(sets) * iconHeight
        let totalSpacing = CGFloat(max(0, sets - 1)) * spacing
        let timerHeight: CGFloat = timerSeconds > 0 ? 24.0 : 0.0
        return totalIconHeight + totalSpacing + verticalPadding + timerHeight
    }
    
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
