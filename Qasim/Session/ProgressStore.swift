import Foundation

struct DayFocus: Identifiable, Codable, Hashable {
    var day: String
    var focusedSeconds: TimeInterval
    var distractedSeconds: TimeInterval
    var sessions: Int

    var id: String { day }

    var focusMinutes: Int { Int(focusedSeconds / 60) }
    var totalSeconds: TimeInterval { focusedSeconds + distractedSeconds }
    var focusPercent: Double {
        guard totalSeconds > 0 else { return 0 }
        return focusedSeconds / totalSeconds * 100
    }
}

enum ActivityKind: String, Codable, CaseIterable {
    case website
    case application

    var title: String {
        switch self {
        case .website: "Website"
        case .application: "App"
        }
    }

    var icon: String {
        switch self {
        case .website: "globe"
        case .application: "square.stack.3d.up"
        }
    }
}

struct ActivityStat: Identifiable, Codable, Hashable {
    var name: String
    var kind: ActivityKind
    var focusedSeconds: TimeInterval
    var distractedSeconds: TimeInterval
    var visits: Int
    /// The stable source identity: an app bundle ID or a website host.
    var sourceIdentifier: String?

    init(
        name: String,
        kind: ActivityKind,
        focusedSeconds: TimeInterval,
        distractedSeconds: TimeInterval,
        visits: Int,
        sourceIdentifier: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.focusedSeconds = focusedSeconds
        self.distractedSeconds = distractedSeconds
        self.visits = visits
        self.sourceIdentifier = sourceIdentifier
    }

    var id: String { "\(kind.rawValue):\(name)" }
    var totalSeconds: TimeInterval { focusedSeconds + distractedSeconds }
    var focusPercent: Double {
        guard totalSeconds > 0 else { return 0 }
        return focusedSeconds / totalSeconds * 100
    }
}

struct HourlyActivity: Identifiable, Hashable {
    var hour: Int
    var focusedSeconds: TimeInterval
    var distractedSeconds: TimeInterval

    var id: Int { hour }
    var label: String {
        let suffix = hour < 12 ? "AM" : "PM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return "\(displayHour)\(suffix)"
    }
}

struct SessionRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var taskTitle: String
    var durationMinutes: Int
    var strategy: FocusStrategy
    var finished: Bool
    var focusedSeconds: TimeInterval
    var distractedSeconds: TimeInterval
    var activities: [ActivityStat]
    var hourlyFocusedSeconds: [TimeInterval]
    var hourlyDistractedSeconds: [TimeInterval]

    init(
        id: UUID,
        date: Date,
        taskTitle: String,
        durationMinutes: Int,
        strategy: FocusStrategy,
        finished: Bool,
        focusedSeconds: TimeInterval = 0,
        distractedSeconds: TimeInterval = 0,
        activities: [ActivityStat] = [],
        hourlyFocusedSeconds: [TimeInterval] = Array(repeating: 0, count: 24),
        hourlyDistractedSeconds: [TimeInterval] = Array(repeating: 0, count: 24)
    ) {
        self.id = id
        self.date = date
        self.taskTitle = taskTitle
        self.durationMinutes = durationMinutes
        self.strategy = strategy
        self.finished = finished
        self.focusedSeconds = focusedSeconds
        self.distractedSeconds = distractedSeconds
        self.activities = activities
        self.hourlyFocusedSeconds = hourlyFocusedSeconds
        self.hourlyDistractedSeconds = hourlyDistractedSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, taskTitle, durationMinutes, strategy, finished
        case focusedSeconds, distractedSeconds, activities
        case hourlyFocusedSeconds, hourlyDistractedSeconds
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        date = try values.decode(Date.self, forKey: .date)
        taskTitle = try values.decode(String.self, forKey: .taskTitle)
        durationMinutes = try values.decode(Int.self, forKey: .durationMinutes)
        strategy = try values.decode(FocusStrategy.self, forKey: .strategy)
        finished = try values.decode(Bool.self, forKey: .finished)
        focusedSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .focusedSeconds) ?? 0
        distractedSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .distractedSeconds) ?? 0
        activities = try values.decodeIfPresent([ActivityStat].self, forKey: .activities) ?? []
        hourlyFocusedSeconds = try values.decodeIfPresent([TimeInterval].self, forKey: .hourlyFocusedSeconds)
            ?? Array(repeating: 0, count: 24)
        hourlyDistractedSeconds = try values.decodeIfPresent([TimeInterval].self, forKey: .hourlyDistractedSeconds)
            ?? Array(repeating: 0, count: 24)
    }

    var totalSeconds: TimeInterval { focusedSeconds + distractedSeconds }
    var focusPercent: Double {
        guard totalSeconds > 0 else { return 0 }
        return focusedSeconds / totalSeconds * 100
    }
}

@Observable
@MainActor
final class ProgressStore {
    private let key = "qasim.progress.days"
    private let sessionsKey = "qasim.progress.sessions"
    private(set) var days: [String: DayFocus] = [:]
    private(set) var recentSessions: [SessionRecord] = []

    init() {
        load()
    }

    func record(
        focused: TimeInterval,
        distracted: TimeInterval,
        finishedSession: Bool,
        taskTitle: String,
        durationMinutes: Int,
        strategy: FocusStrategy,
        activities: [ActivityStat] = [],
        hourlyFocusedSeconds: [TimeInterval] = Array(repeating: 0, count: 24),
        hourlyDistractedSeconds: [TimeInterval] = Array(repeating: 0, count: 24)
    ) {
        let stamp = Self.stamp(Date())
        var row = days[stamp] ?? DayFocus(day: stamp, focusedSeconds: 0, distractedSeconds: 0, sessions: 0)
        row.focusedSeconds += max(0, focused)
        row.distractedSeconds += max(0, distracted)
        if finishedSession { row.sessions += 1 }
        days[stamp] = row

        let entry = SessionRecord(
            id: UUID(),
            date: Date(),
            taskTitle: taskTitle,
            durationMinutes: durationMinutes,
            strategy: strategy,
            finished: finishedSession,
            focusedSeconds: max(0, focused),
            distractedSeconds: max(0, distracted),
            activities: activities,
            hourlyFocusedSeconds: hourlyFocusedSeconds,
            hourlyDistractedSeconds: hourlyDistractedSeconds
        )
        recentSessions.insert(entry, at: 0)

        save()
    }

    func focus(on date: Date) -> DayFocus {
        let stamp = Self.stamp(date)
        return days[stamp] ?? DayFocus(day: stamp, focusedSeconds: 0, distractedSeconds: 0, sessions: 0)
    }

    func daySeries(last count: Int, ending date: Date = Date()) -> [DayFocus] {
        guard count > 0 else { return [] }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date)
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(count - offset - 1), to: end) else { return nil }
            return focus(on: day)
        }
    }

    func sessions(since date: Date) -> [SessionRecord] {
        recentSessions.filter { $0.date >= date }
    }

    func sessions(on date: Date) -> [SessionRecord] {
        recentSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func activityTotals(since date: Date) -> [ActivityStat] {
        activityTotals(for: sessions(since: date))
    }

    func activityTotals(on date: Date) -> [ActivityStat] {
        activityTotals(for: sessions(on: date))
    }

    func hourlyActivity(since date: Date) -> [HourlyActivity] {
        var focused = Array(repeating: 0.0, count: 24)
        var distracted = Array(repeating: 0.0, count: 24)
        for session in sessions(since: date) {
            for hour in 0..<24 {
                if session.hourlyFocusedSeconds.indices.contains(hour) {
                    focused[hour] += session.hourlyFocusedSeconds[hour]
                }
                if session.hourlyDistractedSeconds.indices.contains(hour) {
                    distracted[hour] += session.hourlyDistractedSeconds[hour]
                }
            }
        }
        return (0..<24).map {
            HourlyActivity(hour: $0, focusedSeconds: focused[$0], distractedSeconds: distracted[$0])
        }
    }

    private func activityTotals(for sessions: [SessionRecord]) -> [ActivityStat] {
        var totals: [String: ActivityStat] = [:]
        for session in sessions {
            for activity in session.activities {
                if var total = totals[activity.id] {
                    total.focusedSeconds += activity.focusedSeconds
                    total.distractedSeconds += activity.distractedSeconds
                    total.visits += activity.visits
                    totals[activity.id] = total
                } else {
                    totals[activity.id] = activity
                }
            }
        }
        return totals.values.sorted { $0.totalSeconds > $1.totalSeconds }
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
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: DayFocus].self, from: data) {
            days = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            recentSessions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: key)
        }
        if let data = try? JSONEncoder().encode(recentSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func date(from stamp: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: stamp)
    }

    static func selfCheck() {
        let activity = ActivityStat(
            name: "example.com",
            kind: .website,
            focusedSeconds: 60,
            distractedSeconds: 30,
            visits: 1,
            sourceIdentifier: "example.com"
        )
        assert(activity.totalSeconds == 90)
        assert(abs(activity.focusPercent - 66.6666666667) < 0.001)
        assert(activity.sourceIdentifier == "example.com")
    }
}
