import Foundation

struct RecurrenceRule: Codable, Equatable {

    enum Frequency: String, Codable, CaseIterable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    // MARK: - Properties

    var frequency: Frequency
    var interval: Int                     // Every N days/weeks/etc (default 1)
    var daysOfWeek: Set<Int>?            // 1=Sunday, 2=Monday, ... 7=Saturday
    var endDate: Date?                    // nil = forever

    // MARK: - Common Presets

    static let daily = RecurrenceRule(frequency: .daily, interval: 1)

    static let weekdays = RecurrenceRule(
        frequency: .weekly,
        interval: 1,
        daysOfWeek: [2, 3, 4, 5, 6]  // Mon-Fri
    )

    static let weekends = RecurrenceRule(
        frequency: .weekly,
        interval: 1,
        daysOfWeek: [1, 7]  // Sun, Sat
    )

    static let weekly = RecurrenceRule(frequency: .weekly, interval: 1)

    static let biweekly = RecurrenceRule(frequency: .weekly, interval: 2)

    static let monthly = RecurrenceRule(frequency: .monthly, interval: 1)

    static let yearly = RecurrenceRule(frequency: .yearly, interval: 1)

    // MARK: - Day-specific presets

    static func every(_ weekday: Int) -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [weekday])
    }

    // MARK: - Computed

    var displayName: String {
        if daysOfWeek == [2, 3, 4, 5, 6] {
            return "Weekdays"
        } else if daysOfWeek == [1, 7] {
            return "Weekends"
        }

        switch frequency {
        case .daily:
            return interval == 1 ? "Daily" : "Every \(interval) days"
        case .weekly:
            if let days = daysOfWeek, days.count == 1, let day = days.first {
                return "Every \(weekdayName(day))"
            }
            return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case .monthly:
            return interval == 1 ? "Monthly" : "Every \(interval) months"
        case .yearly:
            return interval == 1 ? "Yearly" : "Every \(interval) years"
        }
    }

    // MARK: - Next Occurrence

    func nextOccurrence(after date: Date) -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date

        case .weekly:
            if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                // Find next matching day
                var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
                let sortedDays = daysOfWeek.sorted()

                for _ in 0..<14 {  // Search up to 2 weeks
                    let weekday = calendar.component(.weekday, from: nextDate)
                    if sortedDays.contains(weekday) {
                        return nextDate
                    }
                    nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
                }
                return nextDate
            } else {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
            }

        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date

        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        }
    }

    // MARK: - Helpers

    private func weekdayName(_ weekday: Int) -> String {
        let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard weekday >= 1 && weekday <= 7 else { return "" }
        return names[weekday]
    }
}
