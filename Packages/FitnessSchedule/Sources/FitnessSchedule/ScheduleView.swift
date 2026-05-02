import SwiftUI
import FitnessCore
import FitnessResources
import FitnessStorage
import FitnessUI
import Factory

public struct ScheduleView: View {
    @State private var viewModel = ScheduleViewModel()
    @Injected(\.workoutStorage) private var workoutStorage
    @Environment(UIOverlayState.self) private var overlayState
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()

    public init() {}

    public var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerView

                    ScheduleCalendarView(
                        selectedDate: $selectedDate,
                        trainingDays: viewModel.trainingDaySet,
                        datesWithData: viewModel.datesWithData,
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
                        WorkoutPickerView(
                            workouts: workoutStorage.workouts,
                            currentWorkout: workoutStorage.currentWorkout,
                            onSelect: { workoutStorage.setCurrentWorkout($0) }
                        )
                    }
                    .zIndex(4)
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Schedule")
        .onAppear { viewModel.reloadData() }
        .onChange(of: workoutStorage.currentWorkout) { _ in
            viewModel.reloadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        WorkoutDropdownView(workoutName: workoutStorage.currentWorkout?.name ?? L10n.workoutFallbackName, titleFont: AppStyle.Font.analyticsExerciseTitle)
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
}
