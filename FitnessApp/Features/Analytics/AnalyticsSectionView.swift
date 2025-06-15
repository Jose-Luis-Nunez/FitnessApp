import SwiftUI

struct AnalyticsSectionView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    @State private var isActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: -24) {
            Button(action: {
                isActive = true
            }) {
                AppIconView(styled: StyledExerciseField(field: .action(.analyticsIcon)))
            }
            .buttonStyle(PlainButtonStyle())

            TextView(styled: StyledExerciseField(field: .action(.analyticsText)))
                .offset(x: 10)
        }
        .navigationDestination(isPresented: $isActive) {
            AnalyticsView(exercise: exercise, viewModel: viewModel)
        }
    }
}
