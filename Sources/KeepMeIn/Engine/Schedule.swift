import Foundation

enum Schedule {
    @MainActor
    static func isActive(at date: Date, settings: AppSettings, calendar: Calendar = .current) -> Bool {
        guard settings.scheduleEnabled else { return true }

        let weekday = calendar.component(.weekday, from: date)
        guard settings.scheduleWeekdays.contains(weekday) else { return false }

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = settings.scheduleStartMinutes
        let end = settings.scheduleEndMinutes

        if start == end { return true }
        if start < end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end // window crosses midnight
    }
}
