import SwiftUI

struct InactiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    let onEdit: (Exercise, ExerciseEditMode) -> Void
    let isEditable: Bool
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    let onReset: ((Exercise) -> Void)?
    let isResetEnabled: Bool
    
    @State private var isShowingAnalytics = false
    @State private var isExpanded = false
    
    private var setProgress: [SetProgress] {
        let latestEntry = analyticsViewModel
            .loadAnalytics(for: viewModel.exercise.id)
            .max(by: { $0.date < $1.date })
        return latestEntry?.setProgress ?? []
    }
    
    var body: some View {
        CardBackground(useGlassEffect: true, addPadding: false) {
            VStack(spacing: 0) {
                headerRow
                
                if isExpanded {
                    Spacer().frame(height: 10)
                    setTilesRow.frame(height: 60)
                    Spacer().frame(height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                AppStyle.Color.greenGlow
                    .frame(width: 8)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $isShowingAnalytics) {
            AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel)
        }
    }
}

// MARK: - Header

private extension InactiveCardView {
    
    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            checkmarkIcon
        }
    }
    
    var categoryIconView: some View {
        Image(viewModel.exercise.displayIconName)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50, alignment: viewModel.exercise.iconAlignment)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
    }
    
    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.exercise.name)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(ExerciseIDs.nameLabel)
                .onTapGesture {
                    if isEditable { onEdit(viewModel.exercise, .name) }
                }
            
            HStack(spacing: 4) {
                Text("Completed workout")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var checkmarkIcon: some View {
        ZStack {
            Circle()
                .fill(AppStyle.Color.greenGlow)
                .frame(width: 36, height: 36)
            
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(AppStyle.Color.exerciseCardBackground)
        }
        .onTapGesture { isExpanded.toggle() }
    }
}

// MARK: - Set Tiles

private extension InactiveCardView {
    
    var setTilesRow: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let hasMoreThan3 = setProgress.count > 3
            let scrollChevronWidth: CGFloat = 8
            let chevronArea: CGFloat = hasMoreThan3 ? scrollChevronWidth + spacing : 0
            let resetTotal: CGFloat = isResetEnabled ? ResetButton.Constants.size + spacing : 0
            let scrollAreaWidth = geo.size.width - resetTotal - chevronArea
            let tileWidth = (scrollAreaWidth - spacing * 2) / 3
            
            HStack(spacing: spacing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(setProgress.indices, id: \.self) { index in
                            let item = setProgress[index]
                            SetTileView(setNumber: index + 1, weight: item.weight, reps: item.currentReps, hasWeight: viewModel.exercise.hasWeight)
                                .frame(width: tileWidth)
                        }
                    }
                }
                .frame(width: scrollAreaWidth)
                .onTapGesture { isShowingAnalytics = true }
                
                if hasMoreThan3 {
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: scrollChevronWidth)
                }
                
                if isResetEnabled {
                    ResetButton { onReset?(viewModel.exercise) }
                }
            }
        }
    }
}

// MARK: - Subviews

extension InactiveCardView {
    
    struct ResetButton: View {
        let onTap: () -> Void

        fileprivate enum Constants {
            static let size: CGFloat = 40
            static let iconSize: CGFloat = 32
        }

        var body: some View {
            Button(action: onTap) {
                Image("repeat")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Constants.iconSize, height: Constants.iconSize)
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .frame(width: Constants.size, height: Constants.size)
                    .background(AppStyle.Color.exerciseCardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    struct SetTileView: View {
        let setNumber: Int
        let weight: Double
        let reps: Int
        let hasWeight: Bool
        
        private var weightText: String {
            weight == floor(weight)
                ? "\(Int(weight))"
                : String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ",")
        }
        
        var body: some View {
            VStack(spacing: 2) {
                Text("SET \(setNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                
                if hasWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(weightText)
                            .font(.system(size: 16, weight: .bold))
                        Text("kg")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    
                    Text("\(reps) reps")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Text("\(reps)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)
                    
                    Text("reps")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
