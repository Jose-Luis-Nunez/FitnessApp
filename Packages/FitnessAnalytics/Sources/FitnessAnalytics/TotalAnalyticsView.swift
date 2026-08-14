import FitnessCore
import FitnessResources
import FitnessStorage
import FitnessUI
import SwiftUI
import Factory

// MARK: - Analytics Tile Data Model

public struct AnalyticsTileData: Identifiable {
    public var id: Kind { kind }
    public let kind: Kind
    public let type: TileType
    public let value: AnalyticsTileValue
    public let label: AnalyticsTileLabel

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

    public init(kind: Kind, type: TileType, value: AnalyticsTileValue, label: AnalyticsTileLabel) {
        self.kind = kind
        self.type = type
        self.value = value
        self.label = label
    }
}

public enum AnalyticsTileValue: Equatable, Sendable {
    case number(Int)
    case percentage(Int)
    case rhythm(TrainingRhythm)
    case category(MuscleCategoryGroup)
}

public enum AnalyticsTileLabel: Equatable, Sendable {
    case trainingMonth(Date)
    case trainingYear(Int)
    case lastWorkoutCompletion
    case trainingRhythm
    case mostTrainedCategory
    case leastTrainedCategory
    case mostImprovedCategory
}

public struct TotalAnalyticsView: View {
    @Environment(\.appColorTheme) var appColorTheme
    @Environment(\.locale) var locale
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
                    title: AppText.analyticsTrainingCalendar
                )
            }
        }
        .background(AppStyle.Color.backgroundColor)
        .standardToolbar(title: AppText.analyticsTotalAnalytics)
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
                    Text(AppText.analyticsTotalOverview)
                        .font(AppStyle.Font.analyticsExerciseTitle)
                        .foregroundColor(AppStyle.Color.white)
                        .fixedSize()

                    if let currentWorkout = workoutStorageService.currentWorkout {
                        Text(AppText.workoutTitleWithName(name: currentWorkout.name))
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
                        Text(verbatim: selectedDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits).locale(locale)))
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
                    number: tileValue(tile.value),
                    label: tileLabel(tile.label)
                )
            case .text:
                AnalyticsTileTextView(
                    text: tileValue(tile.value),
                    label: tileLabel(tile.label)
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

    private func tileValue(_ value: AnalyticsTileValue) -> String {
        switch value {
        case .number(let number): number.formatted(.number.locale(locale))
        case .percentage(let number): "\(number.formatted(.number.locale(locale)))%"
        case .rhythm(let rhythm): AppText.resolve(rhythm.localizedResource, locale: locale)
        case .category(let category): AppText.resolve(category.localizedName, locale: locale)
        }
    }

    private func tileLabel(_ label: AnalyticsTileLabel) -> String {
        let resource: LocalizedStringResource
        switch label {
        case .trainingMonth(let date):
            resource = AppText.analyticsTrainingMonth(month: date.formatted(.dateTime.month(.wide).locale(locale)))
        case .trainingYear(let year): resource = AppText.analyticsTrainingYear(year: year)
        case .lastWorkoutCompletion: resource = AppText.analyticsLastWorkoutCompletion
        case .trainingRhythm: resource = AppText.analyticsTrainingRhythm
        case .mostTrainedCategory: resource = AppText.analyticsMostTrainedCategory
        case .leastTrainedCategory: resource = AppText.analyticsLeastTrainedCategory
        case .mostImprovedCategory: resource = AppText.analyticsMostImprovedCategory
        }
        return AppText.resolve(resource, locale: locale)
    }

}
