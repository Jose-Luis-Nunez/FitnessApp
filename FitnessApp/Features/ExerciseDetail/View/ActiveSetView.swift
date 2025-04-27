import SwiftUI

struct ActiveSetView: View {
    let sets: Int
    let exercise: Exercise
    let setProgress: [SetProgress]
    
    private let backgroundColor = AppStyle.Color.primaryButton
    private let iconSizeWidth: CGFloat = 32
    private let iconSizeHeight: CGFloat = 32
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(backgroundColor)
                .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<sets, id: \.self) { index in
                    HStack(spacing: 12) {
                        if index < setProgress.count {
                            switch setProgress[index].action {
                            case .done:
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .foregroundColor(AppStyle.Color.white)
                            case .less:
                                Image(systemName: "stop.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .foregroundColor(AppStyle.Color.white)
                            case .more:
                                Image(systemName: "flame.circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .foregroundColor(AppStyle.Color.white)
                            case .none:
                                Image(systemName: "circle.fill")
                                    .resizable()
                                    .frame(width: iconSizeWidth, height: iconSizeHeight)
                                    .foregroundColor(AppStyle.Color.white)
                            }
                        } else {
                            Image(systemName: "play.fill")
                                .resizable()
                                .frame(width: iconSizeWidth, height: iconSizeHeight)
                                .foregroundColor(AppStyle.Color.white)
                        }
                        
                        if index < setProgress.count {
                            Text("\(setProgress[index].currentReps)/\(exercise.reps)")
                                .font(AppStyle.Font.largeChip)
                                .foregroundColor(AppStyle.Color.white)
                        }
                        
                        if index < setProgress.count {
                            Text("\(setProgress[index].weight)kg")
                                .font(AppStyle.Font.largeChip)
                                .foregroundColor(AppStyle.Color.white)
                        }
                    }
                }
            }
            
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.vertical, 16)
        }
        .frame(height: calculateHeight())
        .cornerRadius(AppStyle.CornerRadius.card)
    }
    
    private func calculateHeight() -> CGFloat {
        let iconHeight = 32.0
        let spacing = 16.0
        let verticalPadding = 16.0 * 2
        let totalIconHeight = CGFloat(sets) * iconHeight
        let totalSpacing = CGFloat(max(0, sets - 1)) * spacing
        return totalIconHeight + totalSpacing + verticalPadding
    }
}
