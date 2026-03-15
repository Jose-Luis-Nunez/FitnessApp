import SwiftUI

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool
    
    @State private var isShowingAnalytics = false
    
    private var setProgress: [SetProgress] {
        let latestEntry = analyticsViewModel.loadAnalytics(for: viewModel.exercise.id).max(by: { $0.date < $1.date })
        return latestEntry?.setProgress ?? []
    }
    
    var body: some View {
        CardBackground(useGlassEffect: true, addPadding: true) {
            VStack(spacing: 12) {
                exerciseTitle
                setTilesRow
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
    
    private var exerciseTitle: some View {
        Text(viewModel.exercise.name)
            .font(AppStyle.Font.cardHeadline)
            .foregroundColor(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("id_label_exercise_name")
            .onTapGesture {
                if isEditable { onEdit(viewModel.exercise) }
            }
    }
    
    private var setTilesRow: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = setProgress.count > 3
            let chevronWidth: CGFloat = hasMoreThan3 ? 16 : 0
            let resetSize: CGFloat = 36
            let resetTotal: CGFloat = isResetEnabled ? resetSize + spacing : 0
            let scrollAreaWidth = geo.size.width - resetTotal - chevronWidth
            let tileWidth = (scrollAreaWidth - spacing * 2) / 3
            
            HStack(spacing: spacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(setProgress.indices, id: \.self) { index in
                            let item = setProgress[index]
                            SetTileView(setNumber: index + 1, weight: item.weight, reps: item.currentReps)
                                .frame(width: tileWidth)
                        }
                    }
                }
                .frame(width: scrollAreaWidth)
                .onTapGesture {
                    isShowingAnalytics = true
                }
                
                if hasMoreThan3 {
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: chevronWidth - spacing)
                }
                
                if isResetEnabled {
                    ResetButton {
                        onReset?(viewModel.exercise)
                    }
                }
            }
        }
        .frame(height: 60)
    }
}

extension InactiveCardView {
    
    struct ResetButton: View {
        let onTap: () -> Void

        private enum Constants {
            static let size: CGFloat = 36
            static let iconSize: CGFloat = 16
            static let iconColor = AppStyle.Color.white
            static let backgroundColor = Color(hex: "#100F15")
            static let borderColor = AppStyle.Color.gray.opacity(0.7)
        }

        var body: some View {
            Button(action: onTap) {
                Image(systemName: "repeat")
                    .font(.system(size: Constants.iconSize, weight: .bold))
                    .foregroundColor(Constants.iconColor)
                    .frame(width: Constants.size, height: Constants.size)
                    .background(Constants.backgroundColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Constants.borderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    struct SetTileView: View {
        let setNumber: Int
        let weight: Double
        let reps: Int
        
        private var weightText: String {
            weight == floor(weight) ? "\(Int(weight))" : String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ",")
        }
        
        var body: some View {
            VStack(spacing: 2) {
                Text("SET \(setNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(weightText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppStyle.Color.white)
                    Text("kg")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppStyle.Color.white)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                
                Text("\(reps) reps")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppStyle.Color.gray.opacity(0.7), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
