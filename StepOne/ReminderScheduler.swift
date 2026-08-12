//
//  ReminderScheduler.swift
//  StepOne
//
//  Daily reminders, scheduled on the device. These are local notifications,
//  so they need no push capability and no server — iOS keeps firing them
//  until they are cancelled, including across launches.
//

import Foundation
import UserNotifications

enum ReminderSlot: String, CaseIterable, Identifiable, Equatable {
    case morning, evening

    var id: String { rawValue }

    /// Stable across launches. Re-scheduling under the same identifier
    /// replaces the pending request, so changing the time can never leave the
    /// old alarm behind.
    var requestID: String { "stepone.reminder.\(rawValue)" }

    var titleKey: String { self == .morning ? "reminderAM" : "reminderPM" }
    var defaultHour: Int { self == .morning ? 9 : 20 }
}

struct ReminderSetting: Equatable {
    var isOn = false
    var hour: Int
    var minute = 0

    var components: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    /// The picker deals in `Date`; only the time of day is ever read back.
    var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    mutating func setTime(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = parts.hour ?? hour
        minute = parts.minute ?? minute
    }
}

final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    private let center = UNUserNotificationCenter.current()

    /// Shows reminders while the app is open. iOS suppresses them by default,
    /// which makes a correctly scheduled reminder look broken to anyone
    /// testing one a minute out.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Asks the first time and reports the stored answer afterwards. Returns
    /// whether reminders may actually be scheduled.
    func requestAuthorization() async -> Bool {
        switch await authorizationStatus() {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    func schedule(_ slot: ReminderSlot, at setting: ReminderSetting, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: slot.requestID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: setting.components, repeats: true)
        )
        try? await center.add(request)
    }

    func cancel(_ slot: ReminderSlot) {
        center.removePendingNotificationRequests(withIdentifiers: [slot.requestID])
    }

    /// What is scheduled right now. The system is the source of truth, so the
    /// screens cannot drift from it — including after a relaunch, where the
    /// app itself remembers nothing.
    func pending() async -> [ReminderSlot: ReminderSetting] {
        var found: [ReminderSlot: ReminderSetting] = [:]
        for request in await center.pendingNotificationRequests() {
            guard
                let slot = ReminderSlot.allCases.first(where: { $0.requestID == request.identifier }),
                let trigger = request.trigger as? UNCalendarNotificationTrigger
            else { continue }

            found[slot] = ReminderSetting(
                isOn: true,
                hour: trigger.dateComponents.hour ?? slot.defaultHour,
                minute: trigger.dateComponents.minute ?? 0
            )
        }
        return found
    }
}
