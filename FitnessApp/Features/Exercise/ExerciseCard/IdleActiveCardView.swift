import Combine
import SwiftUI

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
        let weight = viewModel.exercise.weight
        if weight == floor(weight) {
            return "\(Int(weight)) kg"
        } else {
            return "\(weight)".replacingOccurrences(of: ".", with: ",") + " kg"
        }
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

            HStack(spacing: 0) {
                if viewModel.exercise.hasWeight {
                    Text(formattedWeight)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                        .padding(.trailing, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditable { onEdit(viewModel.exercise, .weight) }
                        }
                } else {
                    Text("\(viewModel.exercise.sets)x\(viewModel.exercise.reps)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize()
                        .padding(.trailing, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditable { onEdit(viewModel.exercise, .weight) }
                        }
                }

                if let seatSetting = viewModel.exercise.seatSetting {
                    HStack(spacing: 4) {
                        Text(seatSetting)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .fixedSize()

                        Image("chairSettings")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditable { onEdit(viewModel.exercise, .seat) }
                    }
                }

                Button(action: {
                    analyticsSheetDate = AnalyticsSheetDate(date: Date())
                }) {
                    Image("analyticsEntry")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)

                if !weightPhases.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .contentShape(Rectangle())
                        .onTapGesture { isExpanded.toggle() }
                }

                Spacer(minLength: 0)
            }
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            .accessibilityIdentifier("id_button_start_exercise")
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
