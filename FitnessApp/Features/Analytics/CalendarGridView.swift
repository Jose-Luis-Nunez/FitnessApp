import SwiftUI

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let highlightedDates: [Date]
    
    @State private var currentMonth: Date = Date()
    
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

    var body: some View {
        VStack(spacing: 12) {
            header

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day.prefix(2))
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    if calendar.isDate(date, equalTo: Date.distantPast, toGranularity: .day) {
                        Color.clear.frame(height: 36)
                    } else {
                        ZStack {
                            Circle()
                                .fill(circleColor(for: date))
                            Text("\(calendar.component(.day, from: date))")
                                .foregroundColor(textColor(for: date))
                        }
                        .frame(width: 36, height: 36)
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(formattedMonthYear(currentMonth))
                .foregroundColor(.white)
                .font(.headline)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
    }

    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        calendar.isDate(d1, inSameDayAs: d2)
    }

    private func isHighlighted(_ date: Date) -> Bool {
        highlightedDates.contains { isSameDay($0, date) }
    }

    private func textColor(for date: Date) -> Color {
        if isSameDay(date, selectedDate) {
            return .black
        } else if isSameDay(date, Date()) {
            return .white
        } else if isHighlighted(date) {
            return AppStyle.Color.greenDark
        } else {
            return .white
        }
    }

    private func circleColor(for date: Date) -> Color {
        if isSameDay(date, selectedDate) {
            return AppStyle.Color.green
        } else if isSameDay(date, Date()) {
            return .white.opacity(0.2)
        } else if isHighlighted(date) {
            return AppStyle.Color.greenGlow
        } else {
            return .clear
        }
    }

    private func formattedMonthYear(_ date: Date) -> String {
        return DateFormatter.germanMonthYear.string(from: date).capitalized
    }

    private func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}
