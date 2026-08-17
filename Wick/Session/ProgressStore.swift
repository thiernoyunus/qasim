import Foundation

struct DayFocus: Identifiable, Codable, Hashable {
    var day: String
    var focusedSeconds: TimeInterval
    var distractedSeconds: TimeInterval
    var sessions: Int

    var id: String { day }

    var focusMinutes: Int { Int(focusedSeconds / 60) }
}

@Observable
@MainActor
final class ProgressStore {
    private let key = "wick.progress.days"
    private(set) var days: [String: DayFocus] = [:]

    init() {
        load()
    }

    func record(focused: TimeInterval, distracted: TimeInterval, finishedSession: Bool) {
        let stamp = Self.stamp(Date())
        var row = days[stamp] ?? DayFocus(day: stamp, focusedSeconds: 0, distractedSeconds: 0, sessions: 0)
        row.focusedSeconds += max(0, focused)
        row.distractedSeconds += max(0, distracted)
        if finishedSession { row.sessions += 1 }
        days[stamp] = row
        save()
    }

    func focus(on date: Date) -> DayFocus {
        let stamp = Self.stamp(date)
        return days[stamp] ?? DayFocus(day: stamp, focusedSeconds: 0, distractedSeconds: 0, sessions: 0)
    }

    func monthGrid(containing date: Date) -> [DayFocus?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let startWeekday = calendar.component(.weekday, from: interval.start)
        let pad = (startWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        var cells: [DayFocus?] = Array(repeating: nil, count: pad)
        for day in 1...daysInMonth {
            var comps = calendar.dateComponents([.year, .month], from: date)
            comps.day = day
            if let d = calendar.date(from: comps) {
                cells.append(focus(on: d))
            }
        }
        return cells
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: DayFocus].self, from: data) else { return }
        days = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
