import SwiftUI

struct AnalyticsSectionView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    
    var body: some View {
        NavigationLink(destination: AnalyticsView(exercise: exercise, viewModel: viewModel)) {
            VStack(alignment: .leading, spacing: -24) {
                AppIconView(styled: StyledExerciseField(field: .action(.analyticsIcon)))
                
                TextView(styled: StyledExerciseField(field: .action(.analyticsText)))
                    .offset(x: 10)
            }
        }
    }
}
