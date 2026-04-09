import Combine
import SwiftUI

private extension VerticalAlignment {
    struct MetricLabelAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.top]
        }
    }

    static let metricLabel = VerticalAlignment(MetricLabelAlignment.self)
}

struct IdleActiveCardView: View {
    @ObservedObject var viewModel: ExerciseCardViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel

    let onEdit: (Exercise, ExerciseEditMode) -> Void
    let isEditable: Bool
    let onStart: ((Exercise) -> Void)?

    @State private var analyticsSheetDate: AnalyticsSheetDate?
    @State private var isExpanded = false
    @State private var weightPhases: [WeightPhase] = []
    @State private var lastTrainingDateFormatted: String?

    private struct AnalyticsSheetDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    private var formattedWeight: String {
        WeightFormatter.displayWeight(viewModel.exercise.weight)
    }

    private static let lastTrainingFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        return f
    }()

    private func refreshPhaseData() {
        if viewModel.exercise.hasWeight {
            weightPhases = analyticsViewModel.weightPhases(for: viewModel.exercise.id)
        } else {
            weightPhases = analyticsViewModel.repsPhases(for: viewModel.exercise.id)
        }
        if let date = analyticsViewModel.lastTrainingDate(for: viewModel.exercise.id) {
            lastTrainingDateFormatted = Self.lastTrainingFormatter.string(from: date)
        } else {
            lastTrainingDateFormatted = nil
        }
    }

    var body: some View {
        CardBackground(backgroundColor: AppStyle.Color.exerciseCardBackground, useGlassEffect: true, addPadding: false) {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 16)

                if isExpanded, !weightPhases.isEmpty {
                    expandedContent
                        .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
            .background {
                if isExpanded {
                    Color.white.opacity(0.06)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .sheet(item: $analyticsSheetDate) { sheetDate in
                AnalyticsView(exercise: viewModel.exercise, viewModel: analyticsViewModel, initialDate: sheetDate.date)
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        .onAppear { refreshPhaseData() }
        .onReceive(
            analyticsViewModel.analyticsDidUpdate
                .filter { $0 == viewModel.exercise.id }
        ) { _ in refreshPhaseData() }
    }
}

// MARK: - Header

private extension IdleActiveCardView {

    var headerRow: some View {
        HStack(spacing: 10) {
            categoryIconView
            titleSection
            Spacer(minLength: 4)
            playButton
        }
    }

    var categoryIconView: some View {
        Image(viewModel.exercise.category.defaultIconName)
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50, alignment: viewModel.exercise.category.iconAlignment)
            .clipped()
            .foregroundColor(AppStyle.Color.white)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
    }

    var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.exercise.name)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    if isEditable { onEdit(viewModel.exercise, .name) }
                }

            metricRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricLabelFont: Font {
        .system(size: 11, weight: .medium)
    }

    private var metricLabelColor: Color {
        .white.opacity(0.5)
    }

    var metricRow: some View {
        HStack(alignment: .metricLabel, spacing: 0) {
            weightColumn

            if !viewModel.exercise.noSeats {
                verticalSeparator
                seatColumn
            }

            verticalSeparator
            progressColumn

            Spacer(minLength: 0)
        }
    }

    var verticalSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 16)
    }

    var weightColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.exercise.hasWeight ? "Weight" : "Reps")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if viewModel.exercise.hasWeight {
                Text(formattedWeight)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            } else {
                Text("\(viewModel.exercise.sets) x \(viewModel.exercise.reps)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .fixedSize()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(viewModel.exercise, .weight) }
        }
    }

    var seatColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Seat")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            if let seat = viewModel.exercise.seatSetting, !seat.isEmpty {
                Text(seat)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                HStack(spacing: 2) {
                    Text("+")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)

                    Image("chairSettings")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable { onEdit(viewModel.exercise, .seat) }
        }
    }

    var progressColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Progress")
                .font(metricLabelFont)
                .foregroundColor(metricLabelColor)
                .fixedSize()
                .alignmentGuide(.metricLabel) { d in d[VerticalAlignment.center] }

            HStack(spacing: 16) {
                Button(action: {
                    analyticsSheetDate = AnalyticsSheetDate(date: Date())
                }) {
                    Image("analyticsEntry")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
                .buttonStyle(.plain)

                if !weightPhases.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .contentShape(Rectangle())
                        .onTapGesture { isExpanded.toggle() }
                }
            }
        }
    }

    @ViewBuilder
    var playButton: some View {
        if let onStart = onStart, !viewModel.exercise.isCompleted {
            Button(action: { onStart(viewModel.exercise) }) {
                ZStack {
                    Circle()
                        .fill(AppStyle.Color.greenGlow)
                        .frame(width: 36, height: 36)

                    Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(AppStyle.Color.exerciseCardBackground)
                }
            }
            .accessibilityIdentifier(MuscleCategoryIDs.startExercise)
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Expanded Content

private extension IdleActiveCardView {

    var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dateString = lastTrainingDateFormatted {
                Text("Last training: \(dateString)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 6)
            }

            phaseTilesRow
        }
        .padding(.top, 4)
    }

    var phaseTilesRow: some View {
        HStack(spacing: 8) {
            ForEach(weightPhases) { phase in
                WeightPhaseTileView(phase: phase, hasWeight: viewModel.exercise.hasWeight)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        analyticsSheetDate = AnalyticsSheetDate(date: phase.startDate)
                    }
            }

            if weightPhases.count < 3 {
                ForEach(0..<(3 - weightPhases.count), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Weight Phase Tile

extension IdleActiveCardView {

    struct WeightPhaseTileView: View {
        let phase: WeightPhase
        let hasWeight: Bool

        private var weightNumber: String {
            phase.weight == floor(phase.weight)
                ? "\(Int(phase.weight))"
                : String(format: "%.1f", phase.weight).replacingOccurrences(of: ".", with: ",")
        }

        private var durationText: String {
            phase.durationDays == 1 ? "Period: 1 Day" : "Period: \(phase.durationDays) Days"
        }

        private static let tileDate: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "dd.MM"
            return f
        }()

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                if hasWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(weightNumber)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)
                        Text("KG")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(phase.maxReps ?? 0)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)
                        Text("Reps")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppStyle.Color.greenGlow)
                    }
                }

                Text(durationText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 4) {
                    Text("\(phase.sessionCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("to")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppStyle.Color.greenGlow)
                }

                Spacer(minLength: 2)

                resultRow(icon: "mappin.and.ellipse", setsReps: phase.startSetsReps, date: phase.startDate, highlight: false)
                resultRow(icon: "flag.fill", setsReps: phase.endSetsReps, date: phase.endDate, highlight: phase.hasImproved)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        private func resultRow(icon: String, setsReps: String, date: Date, highlight: Bool) -> some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(highlight ? AppStyle.Color.greenGlow : .white.opacity(0.5))
                    .frame(width: 14, alignment: .center)
                Text(setsReps)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(highlight ? AppStyle.Color.greenGlow : .white.opacity(0.7))
                Text("(\(Self.tileDate.string(from: date)))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
