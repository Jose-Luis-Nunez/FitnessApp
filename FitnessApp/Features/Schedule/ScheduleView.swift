import SwiftUI

struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @ObservedObject private var workoutStorage = WorkoutStorageService.shared
    @EnvironmentObject private var overlayState: UIOverlayState
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()

    @State private var trainingDaySet: Set<Date> = []
    @State private var datesWithData: Set<Date> = []

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerView

                    ScheduleCalendarView(
                        selectedDate: $selectedDate,
                        trainingDays: trainingDaySet,
                        datesWithData: datesWithData,
                        currentMonth: $currentMonth
                    )
                    .padding(.horizontal, AppStyle.Padding.horizontal)

                    StreakBannerView(streakData: viewModel.streakData())
                        .padding(.horizontal, AppStyle.Padding.horizontal)

                    WeekSummaryView(
                        summary: viewModel.weekSummary(for: selectedDate),
                        selectedDate: selectedDate,
                        onDayTap: { date in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        }
                    )
                    .padding(.horizontal, AppStyle.Padding.horizontal)

                    dayDetailSection
                        .padding(.horizontal, AppStyle.Padding.horizontal)

                    Spacer(minLength: 100)
                }
            }

            if overlayState.showWorkoutDropdown {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            overlayState.showWorkoutDropdown = false
                        }
                    }
                    .overlay {
                        WorkoutPickerView()
                    }
                    .zIndex(4)
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Schedule")
        .onAppear { reloadData() }
        .onChange(of: workoutStorage.currentWorkout) { _ in
            reloadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        WorkoutDropdownView(titleFont: AppStyle.Font.analyticsExerciseTitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppStyle.Padding.horizontal)
            .padding(.top, AppStyle.Padding.titleTop)
    }

    // MARK: - Day Detail

    @ViewBuilder
    private var dayDetailSection: some View {
        let detail = viewModel.dayDetail(for: selectedDate)
        let exerciseCount = viewModel.exerciseCountForDay(selectedDate)

        VStack(alignment: .leading, spacing: 8) {
            Text("Training Details")
                .font(AppStyle.Font.sectionTitle)
                .foregroundColor(AppStyle.Color.white)

            ScheduleDayDetailView(
                date: selectedDate,
                workoutDetail: detail,
                exerciseCount: exerciseCount
            )
        }
    }

    // MARK: - Data

    private func reloadData() {
        trainingDaySet = Set(viewModel.trainingDays())
        datesWithData = viewModel.allDatesWithData()
    }
}
