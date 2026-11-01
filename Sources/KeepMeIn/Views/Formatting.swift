import Foundation

enum Formatting {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let rest = total % 60
        if minutes < 60 { return rest == 0 ? "\(minutes)m" : "\(minutes)m \(rest)s" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()

    static func minutesToDate(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    static func dateToMinutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

extension Formatting {
    /// "00:42:18"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

extension Formatting {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// "today 14:02", "yesterday 09:10", or "1 Nov".
    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today \(shortTime.string(from: date))" }
        if cal.isDateInYesterday(date) { return "yesterday \(shortTime.string(from: date))" }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(cal.isDate(date, equalTo: Date(), toGranularity: .year) ? "d MMM" : "d MMM yyyy")
        return f.string(from: date)
    }
}
