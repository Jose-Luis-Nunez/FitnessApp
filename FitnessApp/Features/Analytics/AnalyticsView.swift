import SwiftUI

struct AnalyticsView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @State private var selectedDate: Date = Date()
    
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
            
            DatePicker(
                "Datum auswählen",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .accentColor(AppStyle.Color.green)
            .foregroundColor(AppStyle.Color.white)
            
            let entries = viewModel.loadAnalytics(for: exercise.id, on: selectedDate)
            if entries.isEmpty {
                Text("Keine Daten für das ausgewählte Datum verfügbar")
                    .font(.body)
                    .foregroundColor(AppStyle.Color.gray)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formattedDate(entry.date))
                                    .font(AppStyle.Font.regularChip)
                                    .foregroundColor(AppStyle.Color.white)
                                
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
