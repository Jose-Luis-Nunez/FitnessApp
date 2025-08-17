import Foundation

extension DateFormatter {
    /// German date formatter with medium style (e.g., "16. August 2025")
    static let germanMedium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    /// German short date formatter (e.g., "16.08.2025")
    static let germanShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    /// German very short date formatter (e.g., "16.08")
    static let germanVeryShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    /// German compact date formatter (e.g., "16.08.25")
    static let germanCompact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    /// German month-year formatter (e.g., "August 2025")
    static let germanMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
