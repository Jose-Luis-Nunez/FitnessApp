import SwiftUI

struct ScheduleCalendarView: View {
    @Binding var selectedDate: Date
    let trainingDays: Set<Date>
    let datesWithData: Set<Date>
    @Binding var currentMonth: Date

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var daysInMonth: [Date] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }

        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? (1..<31)
        let startWeekday = calendar.component(.weekday, from: monthStart)
        let shiftedWeekday = (startWeekday - calendar.firstWeekday + 7) % 7
        let emptyDays = Array(repeating: Date.distantPast, count: shiftedWeekday)

        return emptyDays + range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
    }

    private var kwLabel: String {
        let week = calendar.component(.weekOfYear, from: selectedDate)
        return "KW \(week)"
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayRow
            dayGrid
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .fill(Color.white.opacity(AppStyle.Opacity.subtleBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(Color.white.opacity(AppStyle.Opacity.subtleStroke), lineWidth: 1)
                )
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedMonthYear(currentMonth))
                    .foregroundColor(AppStyle.Color.white)
                    .font(AppStyle.Font.calendarHeader)
                Text(kwLabel)
                    .font(AppStyle.Font.calendarSubheader)
                    .foregroundColor(AppStyle.Color.greenGlow.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppStyle.Color.white)
                }
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppStyle.Color.white)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day.prefix(2))
                    .foregroundColor(AppStyle.Color.gray)
                    .font(AppStyle.Font.calendarSubheader)
            }
        }
    }

    // MARK: - Day Grid

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(daysInMonth, id: \.self) { date in
                if calendar.isDate(date, equalTo: Date.distantPast, toGranularity: .day) {
                    Color.clear.frame(height: 40)
                } else {
                    dayCellView(for: date)
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCellView(for date: Date) -> some View {
        let isSelected = isSameDay(date, selectedDate)
        let isToday = isSameDay(date, Date())
        let isTraining = isTrainingDay(date)
        let hasData = hasAnyData(date)
        let isFuture = date > Date()

        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(circleFill(selected: isSelected, today: isToday, training: isTraining))
                    .overlay(
                        Circle()
                            .stroke(circleStroke(hasData: hasData, training: isTraining, selected: isSelected, today: isToday), lineWidth: 1.5)
                    )

                Text("\(calendar.component(.day, from: date))")
                    .font(isSelected || isTraining ? AppStyle.Font.calendarDayBold : AppStyle.Font.calendarDay)
                    .foregroundColor(textColor(selected: isSelected, today: isToday, training: isTraining, future: isFuture))
            }
            .frame(width: 32, height: 32)

            // Dot indicator below the number
            Circle()
                .fill(dotColor(training: isTraining, hasData: hasData))
                .frame(width: 5, height: 5)
                .opacity(isTraining || hasData ? 1 : 0)
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }

    // MARK: - Styling Helpers

    private func circleFill(selected: Bool, today: Bool, training: Bool) -> Color {
        if selected { return AppStyle.Color.green }
        if today { return Color.white.opacity(0.15) }
        return .clear
    }

    private func circleStroke(hasData: Bool, training: Bool, selected: Bool, today: Bool) -> Color {
        if selected || today { return .clear }
        if training { return AppStyle.Color.greenGlow.opacity(0.5) }
        if hasData { return Color.white.opacity(0.15) }
        return .clear
    }

    private func textColor(selected: Bool, today: Bool, training: Bool, future: Bool) -> Color {
        if selected { return .black }
        if today { return AppStyle.Color.white }
        if training { return AppStyle.Color.greenGlow }
        if future { return Color.white.opacity(0.3) }
        return Color.white.opacity(0.8)
    }

    private func dotColor(training: Bool, hasData: Bool) -> Color {
        if training { return AppStyle.Color.greenGlow }
        if hasData { return AppStyle.Color.greenGlow.opacity(0.35) }
        return .clear
    }

    // MARK: - Date Helpers

    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        calendar.isDate(d1, inSameDayAs: d2)
    }

    private func isTrainingDay(_ date: Date) -> Bool {
        trainingDays.contains { isSameDay($0, date) }
    }

    private func hasAnyData(_ date: Date) -> Bool {
        datesWithData.contains { isSameDay($0, date) }
    }

    private func formattedMonthYear(_ date: Date) -> String {
        DateFormatter.germanMonthYear.string(from: date).capitalized
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentMonth = newMonth
            }
        }
    }
}
