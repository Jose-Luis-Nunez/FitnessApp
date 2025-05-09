import SwiftUI

struct AnalyticsView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    
    init(exercise: Exercise, viewModel: AnalyticsViewModel) {
        self.exercise = exercise
        self.viewModel = viewModel
        self.initialReps = exercise.reps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analytics")
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(AppStyle.Color.white)
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, 16)
            
            let entries = viewModel.loadAnalytics(for: exercise.id)
            if entries.isEmpty {
                Text("Keine Daten verfügbar")
                    .font(.body)
                    .foregroundColor(AppStyle.Color.gray)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(entry.setProgress, id: \.self) { progress in
                                    Text("\(progress.weight) kg \(progress.currentReps)/\(initialReps)")
                                        .font(AppStyle.Font.largeChip)
                                        .foregroundColor(AppStyle.Color.white)
                                }
                            }
                            .padding(.horizontal, AppStyle.Padding.horizontal)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
    }
}
