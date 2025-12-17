import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Notification permission granted: \(granted)")
        }
    }

    // MARK: - Schedule Notification

    func scheduleNotification(for task: TodoItem) {
        // Only schedule if task has a specific time
        guard task.hasSpecificTime,
              let scheduledDate = task.scheduledDate,
              scheduledDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = "Time for your reminder"
        content.sound = .default

        // Create date components trigger
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: scheduledDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Use task ID as identifier for easy cancellation
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for: \(task.title) at \(scheduledDate)")
            }
        }
    }

    // MARK: - Cancel Notification

    func cancelNotification(for taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        print("Notification cancelled for task: \(taskId)")
    }

    // MARK: - Update Notification

    func updateNotification(for task: TodoItem) {
        // Cancel existing notification first
        cancelNotification(for: task.id)

        // Schedule new one if conditions are met
        scheduleNotification(for: task)
    }

    // MARK: - Cancel All

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}
