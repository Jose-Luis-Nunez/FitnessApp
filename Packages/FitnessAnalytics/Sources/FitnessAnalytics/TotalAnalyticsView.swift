import FitnessCore
import FitnessStorage
import FitnessUI
import SwiftUI
import Factory

// MARK: - Analytics Tile Data Model

public struct AnalyticsTileData: Identifiable {
    public let id: UUID
    public let type: TileType
    public let value: String
    public let label: String

    public enum TileType {
        case number
        case text
    }

    public init(id: UUID = UUID(), type: TileType, value: String, label: String) {
        self.id = id
        self.type = type
        self.value = value
        self.label = label
    }
}

public struct TotalAnalyticsView: View {
    public var viewModel: TotalAnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State var showWorkoutDetail: Bool = false
    @State var showRhythmDetail: Bool = false

    @State private var datesWithData: Set<Date> = []

    public init(viewModel: TotalAnalyticsViewModel = TotalAnalyticsViewModel()) {
        self.viewModel = viewModel
    }

    @Injected(\.workoutStorage) private var workoutStorageService

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                CalendarDialogView(
                    isPresented: $showCalendarDialog,
                    selectedDate: $selectedDate,
                    highlightedDates: Array(datesWithData),
                    title: "Training Calendar"
                )
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Total Analytics")
        .onAppear {
            viewModel.refreshData()
            datesWithData = viewModel.allDatesWithData()
        }
    }

    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView

                overallStatsView
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.vertical, 12)

                categoryProgressView
                    .padding(.vertical, 8)

                Spacer()
            }
            .frame(minHeight: geometry.size.height)
        }
        .onTapGesture {
            if showWorkoutDetail {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWorkoutDetail = false
                }
            } else if showRhythmDetail {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRhythmDetail = false
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Overview")
                        .font(AppStyle.Font.analyticsExerciseTitle)
                        .foregroundColor(AppStyle.Color.white)
                        .fixedSize()

                    if let currentWorkout = workoutStorageService.currentWorkout {
                        Text("Workout: \(currentWorkout.name)")
                            .font(AppStyle.Font.detailCaption)
                            .foregroundColor(AppStyle.Color.greenGlow.opacity(0.8))
                    }
                }

                Spacer()

                Button(action: {
                    showCalendarDialog = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(AppStyle.Font.detailCaption)
                        Text(DateFormatter.germanShort.string(from: selectedDate))
                            .font(AppStyle.Font.detailCaption)
                    }
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppStyle.Color.greenBlack.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 15)
        .padding(.bottom, 10)
    }

    private var analyticsTiles: [AnalyticsTileData] {
        let mostTrained = viewModel.getMostTrainedCategory()
        let leastTrained = viewModel.getLeastTrainedCategory()
        let mostImproved = viewModel.getCategoryWithMostImprovements()
        let completionRate = viewModel.getLastTrainingDayCompletionRate()

        return [
            AnalyticsTileData(
                type: .number,
                value: "\(viewModel.totalWorkoutDaysInCurrentMonth())",
                label: "Training \(viewModel.currentMonthName())"
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(viewModel.totalWorkoutDaysInYear())",
                label: "Training \(Calendar.current.component(.year, from: Date()))"
            ),
            AnalyticsTileData(
                type: .number,
                value: "\(completionRate.percentage)%",
                label: "Last Workout Completion"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(viewModel.getTrainingRhythm())",
                label: "Training Rhythm"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostTrained.category.displayName)",
                label: "Category with most exercise"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(leastTrained.category.displayName)",
                label: "Category with least exercise"
            ),
            AnalyticsTileData(
                type: .text,
                value: "\(mostImproved.category.displayName)",
                label: "Category with most Improvements"
            )
        ]
    }

    @ViewBuilder
    private var overallStatsView: some View {
        if showWorkoutDetail {
            workoutDetailView
        } else if showRhythmDetail {
            rhythmDetailView
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(analyticsTiles) { tile in
                    analyticsTileView(for: tile)
                }
            }
        }
    }

    @ViewBuilder
    private func analyticsTileView(for tile: AnalyticsTileData) -> some View {
        let tileView = Group {
            switch tile.type {
            case .number:
                AnalyticsTileNumberView(
                    number: tile.value,
                    label: tile.label
                )
            case .text:
                AnalyticsTileTextView(
                    text: tile.value,
                    label: tile.label
                )
            }
        }

        if tile.label == "Last Workout Completion" {
            tileView
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showWorkoutDetail = true
                    }
                }
        } else if tile.label == "Training Rhythm" {
            tileView
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRhythmDetail = true
                    }
                }
        } else {
            tileView
        }
    }
}
