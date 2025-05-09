import SwiftUI

struct AnalyticsView: View {
    let exercise: Exercise
    @ObservedObject var viewModel: AnalyticsViewModel
    private let initialReps: Int
    @State private var selectedDate: Date = Date()
    @State private var originalDate: Date = Date()
    @State private var tempDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    
    private let backgroundColor = AppStyle.Color.grayDark
    private let paddingAmount: CGFloat = 16

    init(exercise: Exercise, viewModel: AnalyticsViewModel) {
        self.exercise = exercise
        self.viewModel = viewModel
        self.initialReps = exercise.reps
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent
                calendarDialog
            }
        }
    }
    
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            calendarSelectionView
            resultsView
            Spacer()
        }
        .background(AppStyle.Color.backgroundColor)
        .navigationTitle("")
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
    }

    private var headerView: some View {
        Text(exercise.name)
            .font(AppStyle.Font.navigationHeadline)
            .foregroundColor(AppStyle.Color.white)
            .padding(.top, 45)
            .padding(.horizontal, AppStyle.Padding.horizontal)
    }
    
    private var calendarSelectionView: some View {
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
                            showCalendarDialog = true
                        }
                    
                    Text(formattedDate(selectedDate))
                        .font(.body)
                        .foregroundColor(AppStyle.Color.white)
                        .onTapGesture {
                            showCalendarDialog = true
                        }
                }
                .padding(.horizontal, 8)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 8)
    }
    
    private var resultsView: some View {
        let entries = viewModel.loadAnalytics(for: exercise.id, on: selectedDate)
        
        if entries.isEmpty {
            return AnyView(
                Text("Keine Daten für das ausgewählte Datum verfügbar")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(AppStyle.Color.gray)
                    .padding(.horizontal, AppStyle.Padding.horizontal)
            )
        } else {
            return AnyView(
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            entryView(entry)
                        }
                    }
                }
            )
        }
    }
    
    private func entryView(_ entry: AnalyticsEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.setProgress, id: \.self) { progress in
                Text("\(progress.weight) kg \(progress.currentReps) / \(initialReps)")
                    .font(AppStyle.Font.largeChip)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
    }
    
    private var calendarDialog: some View {
        Group {
            if showCalendarDialog {
                VStack(spacing: 16) {
                    VStack {
                        Text("Wähle ein Datum")
                            .font(.headline)
                            .foregroundColor(AppStyle.Color.white)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                        
                        DatePicker(
                            "",
                            selection: $tempDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .accentColor(AppStyle.Color.green)
                        .background(backgroundColor)
                        .cornerRadius(12)
                        .padding([.top, .bottom], 2)
                        .padding(.horizontal, 16)
                        
                        actionButtons
                    }
                    .background(backgroundColor)
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)
                    .padding(16)
                }
                .frame(maxWidth: 400, maxHeight: 250)
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Abbrechen") {
                showCalendarDialog = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
            
            Button("Auswählen") {
                selectedDate = tempDate
                showCalendarDialog = false
            }
            .font(.body)
            .foregroundColor(AppStyle.Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(AppStyle.Color.green)
            .cornerRadius(AppStyle.CornerRadius.defaultButton)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}
