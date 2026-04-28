import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            // Permission errors are non-fatal; the app still functions as a tracker.
        }
    }

    func rescheduleNotifications(for assignments: [Assignment]) async {
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        let courseWatchNotificationIDs = pendingRequests.map(\.identifier).filter {
            $0.hasPrefix("assignment-")
        }

        center.removePendingNotificationRequests(withIdentifiers: courseWatchNotificationIDs)

        for assignment in assignments {
            guard let dueAt = assignment.dueAt else {
                continue
            }

            await scheduleNotification(
                assignment: assignment,
                dueAt: dueAt,
                leadTime: 24 * 60 * 60,
                suffix: "24h",
                title: "Assignment due tomorrow"
            )

            await scheduleNotification(
                assignment: assignment,
                dueAt: dueAt,
                leadTime: 3 * 60 * 60,
                suffix: "3h",
                title: "Assignment due soon"
            )
        }
    }

    private func scheduleNotification(
        assignment: Assignment,
        dueAt: Date,
        leadTime: TimeInterval,
        suffix: String,
        title: String
    ) async {
        let fireDate = dueAt.addingTimeInterval(-leadTime)
        guard fireDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(assignment.name) for \(assignment.courseName)"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: assignment, suffix: suffix),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification scheduling should not block refresh results.
        }
    }

    private func notificationID(for assignment: Assignment, suffix: String) -> String {
        "assignment-\(assignment.courseID)-\(assignment.id)-\(suffix)"
    }
}
