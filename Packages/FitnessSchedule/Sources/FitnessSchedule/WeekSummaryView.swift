import SwiftUI
import FitnessUI

public struct WeekSummaryView: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let summary: WeekSummaryData
    public let selectedDate: Date
    public let onDayTap: (Date) -> Void

    private let calendar = Calendar.current

    public init(summary: WeekSummaryData, selectedDate: Date, onDayTap: @escaping (Date) -> Void) {
        self.summary = summary
        self.selectedDate = selectedDate
        self.onDayTap = onDayTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("KW \(summary.calendarWeek)")
                    .font(AppStyle.Font.sectionTitle)
                    .foregroundColor(AppStyle.Color.white)

                Spacer()

                Text("\(summary.trainingDayCount) Training\(summary.trainingDayCount == 1 ? "" : "s") · \(summary.totalExercises) Exercises")
                    .font(AppStyle.Font.detailCaption)
                    .foregroundColor(appColorTheme.accent.glow.opacity(0.7))
            }

            HStack(spacing: 6) {
                ForEach(summary.days) { day in
                    dayChip(day: day)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .fill(Color.white.opacity(AppStyle.Opacity.subtleBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }

    private func dayChip(day: WeekDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day.date)

        return VStack(spacing: 4) {
            Text(day.label)
                .font(AppStyle.Font.dayChipLabel)
                .foregroundColor(chipLabelColor(trained: day.isTrainingDay, selected: isSelected))

            Text("\(calendar.component(.day, from: day.date))")
                .font(day.isTrainingDay ? AppStyle.Font.dayChipNumberBold : AppStyle.Font.dayChipNumber)
                .foregroundColor(chipNumberColor(trained: day.isTrainingDay, selected: isSelected, today: isToday))

            if day.isTrainingDay {
                Circle()
                    .fill(appColorTheme.accent.glow)
                    .frame(width: 4, height: 4)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(chipBackground(trained: day.isTrainingDay, selected: isSelected, today: isToday))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(chipBorder(trained: day.isTrainingDay, selected: isSelected, today: isToday), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onDayTap(day.date) }
    }

    // MARK: - Chip Styling

    private func chipLabelColor(trained: Bool, selected: Bool) -> Color {
        if selected { return appColorTheme.accent.glow }
        if trained { return appColorTheme.accent.glow.opacity(0.8) }
        return Color.white.opacity(0.4)
    }

    private func chipNumberColor(trained: Bool, selected: Bool, today: Bool) -> Color {
        if selected { return AppStyle.Color.white }
        if trained { return appColorTheme.accent.glow }
        if today { return AppStyle.Color.white }
        return Color.white.opacity(0.6)
    }

    private func chipBackground(trained: Bool, selected: Bool, today: Bool) -> Color {
        if selected { return appColorTheme.accent.primary.opacity(0.25) }
        if trained { return appColorTheme.accent.glow.opacity(0.08) }
        return .clear
    }

    private func chipBorder(trained: Bool, selected: Bool, today: Bool) -> Color {
        if selected { return appColorTheme.accent.glow.opacity(0.4) }
        if today { return Color.white.opacity(0.2) }
        return .clear
    }
}
