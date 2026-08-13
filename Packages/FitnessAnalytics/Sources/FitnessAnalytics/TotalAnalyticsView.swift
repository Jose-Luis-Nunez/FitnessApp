import FitnessCore
import FitnessStorage
import FitnessUI
import SwiftUI
import Factory

// MARK: - Analytics Tile Data Model

public struct AnalyticsTileData: Identifiable {
    public var id: Kind { kind }
    public let kind: Kind
    public let type: TileType
    public let value: String
    public let label: String

    public enum TileType {
        case number
        case text
    }

    public enum Kind: String, Sendable {
        case currentMonthTraining
        case currentYearTraining
        case lastWorkoutCompletion
        case trainingRhythm
        case mostTrainedCategory
        case leastTrainedCategory
        case mostImprovedCategory
    }

    public init(kind: Kind, type: TileType, value: String, label: String) {
        self.kind = kind
        self.type = type
        self.value = value
        self.label = label
    }
}

public struct TotalAnalyticsView: View {
    @Environment(\.appColorTheme) var appColorTheme
    @State private var viewModel: TotalAnalyticsViewModel
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDialog: Bool = false
    @State var showWorkoutDetail: Bool = false
    @State var showRhythmDetail: Bool = false

    @MainActor
    public init() {
        _viewModel = State(initialValue: TotalAnalyticsViewModel())
    }

    @MainActor
    public init(viewModel: TotalAnalyticsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @Injected(\.workoutStorage) private var workoutStorageService

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry: geometry)
                CalendarDialogView(
                    isPresented: $showCalendarDialog,
                    selectedDate: $selectedDate,
                    highlightedDates: Array(viewModel.displayState.datesWithData),
                    title: "Training Calendar"
                )
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: "Total Analytics")
        .onAppear {
            viewModel.materializeDisplayState()
        }
    }

    var categoryProgressData: [CategoryProgressData] {
        viewModel.displayState.categoryProgress
    }

    var workoutDetailData: WorkoutDetailData? {
        viewModel.displayState.workoutDetail
    }

    var rhythmDetailData: TrainingRhythmDetailData? {
        viewModel.displayState.rhythmDetail
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
                            .foregroundColor(appColorTheme.accent.glow.opacity(0.8))
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
                    .foregroundColor(appColorTheme.accent.glow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appColorTheme.accent.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(appColorTheme.accent.glow.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, AppStyle.Padding.horizontal)
        .padding(.top, 15)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var overallStatsView: some View {
        if showWorkoutDetail {
            workoutDetailView
        } else if showRhythmDetail {
            rhythmDetailView
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(viewModel.displayState.tiles) { tile in
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

        switch tile.kind {
        case .lastWorkoutCompletion:
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWorkoutDetail = true
                }
            } label: {
                tileView
            }
            .buttonStyle(.plain)
        case .trainingRhythm:
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRhythmDetail = true
                }
            } label: {
                tileView
            }
            .buttonStyle(.plain)
        case .currentMonthTraining,
             .currentYearTraining,
             .mostTrainedCategory,
             .leastTrainedCategory,
             .mostImprovedCategory:
            tileView
        }
    }
}
