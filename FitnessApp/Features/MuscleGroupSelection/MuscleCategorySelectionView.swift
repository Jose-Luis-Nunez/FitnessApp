import SwiftUI

private struct IDS {
    static func label(for group: MuscleCategoryGroup) -> String { "id_label_\(group.id)" }
}

struct MuscleCategorySelectionView: View {
    @StateObject private var viewModel = MuscleCategorySelectionViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Text("Kategorien")
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer().frame(height: 30)
                
                ForEach(MuscleCategoryGroup.allCases, id: \.self) { group in
                    NavigationLink(value: NavigationDestination.muscleCategory(group)) {
                        CategoryTileView(group: group, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 5)
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitle("")
        .onAppear { viewModel.updateExerciseCounts() }
    }
}

private struct CategoryTileView: View {
    
    private let kBarWidth: CGFloat = 120
    
    let group: MuscleCategoryGroup
    @ObservedObject var viewModel: MuscleCategorySelectionViewModel
    
    var body: some View {
        let (total, active, isCompleted, progress) = exerciseInfo
        
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(group.displayName)
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)
                
                Text("\(active) von \(total) Übungen")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(Color(hex: "#8a8580"))
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)
            
            Spacer()
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 18) {
                    CustomChip(
                        text: isCompleted ? "Completed" : "Active",
                        isCompleted: isCompleted,
                        width: kBarWidth
                    )
                    .accessibilityIdentifier(IDS.label(for: group))
                    
                    ProgressBar(progress: progress, totalWidth: kBarWidth)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppStyle.Color.white)
                    .imageScale(.medium)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 15)
        }
        .frame(maxWidth: .infinity)
        .background(AppStyle.Color.exerciseCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }
    
    private var exerciseInfo: (total: Int, active: Int, completed: Bool, progress: Double) {
        let cnt   = viewModel.getExerciseCount(for: group) ?? (0, 0)
        let total = cnt.total
        let active = cnt.active
        let completed = (active == 0 && total > 0)
        let progress  = total > 0 ? Double(total - active) / Double(total) : 0.0
        return (total, active, completed, progress)
    }
}

private struct CustomChip: View {
    let text: String
    let isCompleted: Bool
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(AppStyle.Font.defaultFont)
            .foregroundColor(.white)
            .frame(width: width)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? AppStyle.Color.green : AppStyle.Color.exerciseCardBackground)
            )
            .overlay(
                isCompleted
                ? nil
                : RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#8a8580"), lineWidth: 1)
            )
    }
}

private struct ProgressBar: View {
    let progress: Double
    let totalWidth: CGFloat
    
    private let height: CGFloat = 10
    private let strokeWidth: CGFloat = 1
    private let cornerRadius: CGFloat = 8
    
    private let fillColor  = AppStyle.Color.green
    private let trackColor = Color(hex: "#8a8580")
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .strokeBorder(trackColor, lineWidth: strokeWidth)
                .background(
                    Capsule()
                        .fill(AppStyle.Color.exerciseCardBackground)
                )
                .frame(width: totalWidth, height: height)
            
            Capsule()
                .fill(fillColor)
                .frame(width: CGFloat(progress.clamped(to: 0...1)) * totalWidth,
                       height: height)
        }
        .frame(width: totalWidth, height: height)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
