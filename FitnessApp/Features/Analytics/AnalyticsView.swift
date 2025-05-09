import SwiftUI

struct AnalyticsView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @State private var selectedDate: Date = Date()
    @State private var originalDate: Date = Date()
    @State private var isDatePickerPresented: Bool = false
    @State private var tempDate: Date = Date()
    
    init(exercise: Exercise, viewModel: AnalyticsViewModel) {
        self.exercise = exercise
        self.viewModel = viewModel
        self.initialReps = exercise.reps
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                Text("Ergebnisse")
                    .font(AppStyle.Font.navigationHeadline)
                    .foregroundColor(AppStyle.Color.white)
                    .padding(.top, 16)
                    .padding(.horizontal, AppStyle.Padding.horizontal)

                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppStyle.Color.green, lineWidth: 2)
                            .frame(height: 32)

                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(AppStyle.Color.white)
                                .imageScale(.medium)
                                .onTapGesture {
                                    tempDate = selectedDate
                                    isDatePickerPresented = true
                                }

                            Text(formattedDate(selectedDate))
                                .font(.body)
                                .foregroundColor(AppStyle.Color.white)
                                .onTapGesture {
                                    tempDate = selectedDate
                                    isDatePickerPresented = true
                                }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, 8)
                
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
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Analytics")
                        .font(AppStyle.Font.navigationHeadline)
                        .foregroundColor(AppStyle.Color.white)
                }
            }
            .onAppear {
                originalDate = selectedDate
            }
            .sheet(isPresented: $isDatePickerPresented) {
                VStack(spacing: 16) {
                    DatePicker(
                        "",
                        selection: $tempDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .accentColor(AppStyle.Color.green)
                    .foregroundColor(AppStyle.Color.white)
                    .labelsHidden()
                    .padding()
                    
                    HStack(spacing: 16) {
                        Button("Abbrechen") {
                            isDatePickerPresented = false
                        }
                        .font(.body)
                        .foregroundColor(AppStyle.Color.gray)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppStyle.Color.black)
                        .cornerRadius(AppStyle.CornerRadius.card)
                        
                        Button("Auswählen") {
                            selectedDate = tempDate
                            isDatePickerPresented = false
                        }
                        .font(.body)
                        .foregroundColor(AppStyle.Color.green)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppStyle.Color.black)
                        .cornerRadius(AppStyle.CornerRadius.card)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .background(AppStyle.Color.backgroundColor)
                .presentationDetents([.medium])
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}
