import Foundation
import SwiftData

@Model
final class TodoItem {
    // MARK: - Identity
    var id: UUID = UUID()

    // MARK: - Content
    var title: String = ""
    var rawInput: String = ""  // Original user input preserved for reference

    // MARK: - Temporal
    var scheduledDate: Date?      // nil = no specific date/time
    var hasSpecificTime: Bool = false     // Distinguishes "tomorrow" vs "tomorrow at 3pm"

    // MARK: - Recurrence
    var recurrenceData: Data?     // Encoded RecurrenceRule

    // MARK: - State
    var isCompleted: Bool = false
    var completedAt: Date?

    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortOrder: Int = 0  // For manual reordering

    // MARK: - Computed Properties

    var isReminder: Bool {
        scheduledDate != nil
    }

    var recurrenceRule: RecurrenceRule? {
        get {
            guard let data = recurrenceData else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
        }
        set {
            recurrenceData = try? JSONEncoder().encode(newValue)
        }
    }

    var isRecurring: Bool {
        recurrenceRule != nil
    }

    var displayTime: String? {
        guard let date = scheduledDate, hasSpecificTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var displayDate: String? {
        guard let date = scheduledDate else { return nil }
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return hasSpecificTime ? displayTime : "Today"
        } else if calendar.isDateInTomorrow(date) {
            return hasSpecificTime ? "Tomorrow \(displayTime ?? "")" : "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = hasSpecificTime ? "MMM d, h:mm a" : "MMM d"
            return formatter.string(from: date)
        }
    }

    // MARK: - Initializer

    init(
        title: String,
        rawInput: String,
        scheduledDate: Date? = nil,
        hasSpecificTime: Bool = false,
        recurrenceRule: RecurrenceRule? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.rawInput = rawInput
        self.scheduledDate = scheduledDate
        self.hasSpecificTime = hasSpecificTime
        self.recurrenceData = try? JSONEncoder().encode(recurrenceRule)
        self.isCompleted = false
        self.completedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = Int(Date().timeIntervalSince1970 * 1000)  // Default: timestamp-based
    }

    // MARK: - Actions

    func complete() {
        isCompleted = true
        completedAt = Date()
        updatedAt = Date()

        // If recurring, schedule next occurrence
        if let rule = recurrenceRule, let currentDate = scheduledDate {
            scheduledDate = rule.nextOccurrence(after: currentDate)
            isCompleted = false
            completedAt = nil
        }
    }

    func uncomplete() {
        isCompleted = false
        completedAt = nil
        updatedAt = Date()
    }

    func toggleCompletion() {
        if isCompleted {
            uncomplete()
        } else {
            complete()
        }
    }
}
