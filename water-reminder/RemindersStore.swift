import AppKit
import UserNotifications
import Combine

extension Notification.Name {
    static let remindersShouldReset = Notification.Name("remindersShouldReset")
    static let meetingModeChanged = Notification.Name("meetingModeChanged")
}

final class RemindersStore: ObservableObject {
    static let shared = RemindersStore()

    struct Reminder: Codable, Equatable, Identifiable {
        let id: UUID
        var name: String
        var emoji: String
        var intervalMinutes: Int
        var message: String
        var lastFired: Date?
        var enabled: Bool
    }

    @Published var reminders: [Reminder] {
        didSet { save() }
    }

    @Published var meetingMode: Bool = false {
        didSet {
            if initialized {
                defaults.set(meetingMode, forKey: "com.waterreminder.meetingMode")
                NotificationCenter.default.post(name: .meetingModeChanged, object: nil)
            }
        }
    }

    private var initialized = false
    private let defaults = UserDefaults.standard
    private let key = "com.waterreminder.reminders"
    private let meetingKey = "com.waterreminder.meetingMode"

    private init() {
        if let data = UserDefaults.standard.data(forKey: "com.waterreminder.reminders"),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = decoded
        } else {
            reminders = [
                Reminder(id: UUID(), name: "喝水", emoji: "💧", intervalMinutes: 60,
                         message: "该喝口水啦，保持水分！", lastFired: nil, enabled: true),
                Reminder(id: UUID(), name: "站立", emoji: "🧍", intervalMinutes: 60,
                         message: "站起来活动一下吧，别久坐！", lastFired: nil, enabled: true),
                Reminder(id: UUID(), name: "上厕所", emoji: "🚻", intervalMinutes: 120,
                         message: "去趟卫生间吧，别憋着！", lastFired: nil, enabled: true)
            ]
        }
        meetingMode = defaults.bool(forKey: "com.waterreminder.meetingMode")
        initialized = true
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            defaults.set(data, forKey: key)
        }
    }

    func markFired(_ reminder: Reminder, at date: Date = Date()) {
        guard let idx = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[idx].lastFired = date
    }

    func resetAll() {
        for i in reminders.indices {
            reminders[i].lastFired = nil
        }
        NotificationCenter.default.post(name: .remindersShouldReset, object: nil)
    }

    func restoreDefaults() {
        for i in reminders.indices {
            reminders[i].intervalMinutes = 60
            reminders[i].lastFired = nil
        }
        NotificationCenter.default.post(name: .remindersShouldReset, object: nil)
    }
}