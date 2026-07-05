import AppKit
import UserNotifications
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timers: [UUID: Timer] = [:]
    private let store = RemindersStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var settingsController: NSWindowController?
    private var timerSnapshot: [UUID: (interval: Int, enabled: Bool)] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()

        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        updateStatusIcon()

        store.$reminders
            .receive(on: RunLoop.main)
            .sink { [weak self] reminders in
                guard let self = self else { return }
                self.rebuildMenu()
                self.updateStatusIcon()
                if self.timerSpecChanged(reminders) {
                    self.rebuildTimers()
                } else {
                    // keep existing timers running, drop timers for reminders no longer present
                    let ids = Set(reminders.map { $0.id })
                    for tid in self.timers.keys where !ids.contains(tid) {
                        self.timers[tid]?.invalidate()
                        self.timers[tid] = nil
                    }
                }
            }
            .store(in: &cancellables)

        rebuildTimers()
        rebuildMenu()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(forceResetTimers),
            name: .remindersShouldReset, object: nil)

        NotificationCenter.default.addObserver(
            self, selector: #selector(meetingModeChanged),
            name: .meetingModeChanged, object: nil)
    }

    @objc private func meetingModeChanged() {
        rebuildMenu()
        updateStatusIcon()
    }

    @objc private func forceResetTimers() {
        rebuildTimers()
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async { self.rebuildMenu() }
                    }
                }
            } else if settings.authorizationStatus == .denied {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = "通知权限未开启"
                    alert.informativeText = "请在「系统设置 → 通知 → Water Reminder」中打开「允许通知」，否则无法收到提醒。"
                    alert.addButton(withTitle: "打开系统设置")
                    alert.addButton(withTitle: "取消")
                    let resp = alert.runModal()
                    if resp == .alertFirstButtonReturn {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            if store.meetingMode {
                button.title = "🔇"
            } else {
                let enabledCount = store.reminders.filter { $0.enabled }.count
                if enabledCount == 0 {
                    button.title = "🚫"
                } else {
                    button.title = "💧"
                }
            }
        }
    }

    @objc private func screenDidWake() {
        rebuildTimers()
    }

    private func rebuildTimers() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        timerSnapshot.removeAll()

        for reminder in store.reminders where reminder.enabled {
            let timer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(reminder.intervalMinutes * 60),
                repeats: true) { [weak self] _ in
                self?.fire(reminder)
            }
            timers[reminder.id] = timer
            timerSnapshot[reminder.id] = (reminder.intervalMinutes, reminder.enabled)

            // Also immediately check if overdue since wake / launch
            if let last = reminder.lastFired {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed >= TimeInterval(reminder.intervalMinutes * 60) {
                    fire(reminder)
                }
            } else {
                // first time: do nothing now, schedule naturally
            }
        }
    }

    private func timerSpecChanged(_ reminders: [RemindersStore.Reminder]) -> Bool {
        guard reminders.count == timerSnapshot.count else { return true }
        for r in reminders {
            guard let s = timerSnapshot[r.id] else { return true }
            if s.interval != r.intervalMinutes || s.enabled != r.enabled { return true }
        }
        return false
    }

    private func fire(_ reminder: RemindersStore.Reminder) {
        guard !store.meetingMode else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(reminder.emoji) \(reminder.name)提醒"
        content.body = reminder.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }

        store.markFired(reminder)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "健康提醒助手", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for reminder in store.reminders {
            let item = NSMenuItem(title: "\(reminder.emoji) \(reminder.name) — 每 \(reminder.intervalMinutes) 分钟",
                                  action: #selector(toggle(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = reminder.id
            item.state = reminder.enabled ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let meeting = NSMenuItem(title: store.meetingMode ? "🚫 开会模式（已开启）" : "🎤 开启开会模式",
                                  action: #selector(toggleMeetingMode),
                                  keyEquivalent: "")
        meeting.target = self
        meeting.state = store.meetingMode ? .on : .off
        menu.addItem(meeting)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "偏好设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let reset = NSMenuItem(title: "重置所有计时", action: #selector(resetTimers), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 测试通知"
        content.body = "如果你看到这条通知，说明通知权限已正常工作！"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.messageText = "通知发送失败"
                    alert.informativeText = "\(error.localizedDescription)\n请检查「系统设置 → 通知 → Water Reminder」是否允许通知。"
                    alert.runModal()
                }
            }
        }
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let idx = store.reminders.firstIndex(where: { $0.id == id }) else { return }
        store.reminders[idx].enabled.toggle()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "偏好设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            settingsWindow = window
            settingsController = NSWindowController(window: window)
        }
        settingsController?.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func resetTimers() {
        store.resetAll()
    }

    @objc private func toggleMeetingMode() {
        store.meetingMode.toggle()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}