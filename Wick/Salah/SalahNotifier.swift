import Foundation
import UserNotifications

@MainActor
enum SalahNotifier {
    static func ask() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func refresh(times: [PrayerTimes], leadMinutes: Int, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix("wick.salah.") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard enabled else { return }

        let now = Date()
        for day in times {
            for name in PrayerTimes.salahOrder {
                guard let date = day.times[name] else { continue }
                await add(
                    id: "wick.salah.now.\(name.rawValue).\(Int(date.timeIntervalSince1970))",
                    title: "Time for \(name.title)",
                    body: "The work will wait.",
                    at: date,
                    now: now
                )
                let soon = date.addingTimeInterval(TimeInterval(-leadMinutes * 60))
                await add(
                    id: "wick.salah.soon.\(name.rawValue).\(Int(date.timeIntervalSince1970))",
                    title: "\(name.title) in \(TimePhrase.minutesOnly(leadMinutes))",
                    body: "Wrap this thought.",
                    at: soon,
                    now: now
                )
            }
        }
    }

    private static func add(id: String, title: String, body: String, at date: Date, now: Date) async {
        guard date > now.addingTimeInterval(8) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let bits = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: bits, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
