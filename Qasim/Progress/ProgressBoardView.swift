import AppKit
import SwiftUI

enum AnalyticsTab: Hashable {
    case today
    case history
    case stats

    var title: String {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .stats: "Stats"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .history: "calendar"
        case .stats: "chart.bar.xaxis"
        }
    }
}

struct AnalyticsSection<Content: View>: View {
    var title: String?
    var detail: String?
    let content: Content

    init(title: String? = nil, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || detail != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title)
                            .font(Typeface.display(18, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            content
        }
        .padding(20)
        .background(Palette.cream.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Palette.ink.opacity(0.05), radius: 10, y: 4)
    }
}

struct AnalyticsMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.inkSoft)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.paper.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}

/// The one summary row used by every tab, so Today, History and Stats read the same.
struct AnalyticsSummaryStrip: View {
    let productive: TimeInterval
    let distracted: TimeInterval
    let sessions: Int

    private var score: String {
        let total = productive + distracted
        guard total > 0 else { return "—" }
        return "\(Int((productive / total * 100).rounded()))%"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AnalyticsMetric(label: "Focus score", value: score, color: Palette.ink)
            AnalyticsMetric(label: "Productive", value: Self.duration(productive), color: Palette.good)
            AnalyticsMetric(label: "Distracted", value: Self.duration(distracted), color: Palette.ember)
            AnalyticsMetric(label: "Sessions", value: "\(sessions)", color: Palette.wax)
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct AnalyticsTabPicker: View {
    @Binding var selection: AnalyticsTab

    var body: some View {
        HStack(spacing: 3) {
            ForEach([AnalyticsTab.today, .history, .stats], id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? Palette.cream : Palette.inkSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selection == tab ? Palette.ink : .clear)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.cream.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(Palette.ink.opacity(0.08), lineWidth: 1))
    }
}

struct AnalyticsActivityBreakdown: View {
    let activities: [ActivityStat]
    var limit: Int = 5

    private var totalSeconds: TimeInterval {
        activities.reduce(0) { $0 + $1.totalSeconds }
    }

    private var applications: [ActivityStat] {
        Array(activities.filter { $0.kind == .application }.prefix(limit))
    }

    private var websites: [ActivityStat] {
        Array(activities.filter { $0.kind == .website }.prefix(limit))
    }

    var body: some View {
        if applications.isEmpty || websites.isEmpty {
            activityColumn(
                title: applications.isEmpty ? "Websites" : "Apps",
                caption: applications.isEmpty ? "visited sites" : "tracked apps",
                activities: applications.isEmpty ? websites : applications
            )
        } else {
            HStack(alignment: .top, spacing: 22) {
                activityColumn(title: "Apps", caption: "tracked apps", activities: applications)
                activityColumn(title: "Websites", caption: "visited sites", activities: websites)
            }
        }
    }

    private func activityColumn(
        title: String,
        caption: String,
        activities: [ActivityStat]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Typeface.display(17, weight: .semibold))
                Spacer()
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }

            ForEach(Array(activities.enumerated()), id: \.offset) { index, activity in
                activityRow(activity)
                if index < activities.count - 1 {
                    Divider().opacity(0.22)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func activityRow(_ activity: ActivityStat) -> some View {
        let share = totalSeconds > 0 ? min(1, activity.totalSeconds / totalSeconds) : 0
        let focusColor = activity.focusPercent >= 50 ? Palette.good : Palette.ember

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                AnalyticsActivityLogo(activity: activity)
                Text(activity.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(AnalyticsSummaryStrip.duration(activity.totalSeconds))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.08))
                    Capsule()
                        .fill(focusColor.opacity(0.82))
                        .frame(width: max(6, proxy.size.width * share))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int((share * 100).rounded()))% of time")
                Spacer()
                Text("\(Int(activity.focusPercent.rounded()))% focused")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Palette.inkSoft)
        }
        .padding(.vertical, 9)
    }
}

private struct AnalyticsActivityLogo: View {
    @Environment(AppModel.self) private var model
    let activity: ActivityStat

    private var appIcon: NSImage? {
        if let bundleID = activity.sourceIdentifier,
           let icon = model.catalog.icon(forBundleID: bundleID) {
            return icon
        }
        if let app = model.catalog.search(activity.name).first {
            return model.catalog.icon(for: app)
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.localizedName?.caseInsensitiveCompare(activity.name) == .orderedSame
        }?.icon
    }

    private var websiteLogoURL: URL? {
        guard activity.kind == .website, let host = websiteHost else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    private var websiteHost: String? {
        let value = (activity.sourceIdentifier ?? activity.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard value.contains(".") else { return nil }
        return value
    }

    var body: some View {
        Group {
            if activity.kind == .application, let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else if activity.kind == .website, let websiteLogoURL {
                AsyncImage(url: websiteLogoURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                    } else {
                        fallbackLogo
                    }
                }
            } else if let appIcon {
                // Legacy rows may have an app name but no stable identifier yet.
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                fallbackLogo
            }
        }
        .frame(width: 28, height: 28)
        .background(Palette.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(activity.name)
    }

    private var fallbackLogo: some View {
        Text(activity.kind == .website
            ? String(activity.name.first ?? "?").uppercased()
            : String(activity.name.prefix(2)).uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(activity.kind == .website ? Palette.ember : Palette.inkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProgressBoardView: View {
    @Environment(AppModel.self) private var model
    @State private var month = Date()
    @State private var selectedDay = Date()
    @State private var tab: AnalyticsTab

    init(initialTab: AnalyticsTab = .today) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            switch tab {
            case .today:
                todayContent
            case .history:
                historyContent
            case .stats:
                StatsBoardView()
            }
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text("Analytics")
                    .font(Typeface.display(25, weight: .semibold))
                Text("Your focus, without the noise.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer()
            AnalyticsTabPicker(selection: $tab)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private var todayContent: some View {
        let day = model.progress.focus(on: Date())
        let activities = model.progress.activityTotals(on: Date())
        let sessions = model.progress.sessions(on: Date())

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                todayOverview(day)

                AnalyticsSummaryStrip(
                    productive: day.focusedSeconds,
                    distracted: day.distractedSeconds,
                    sessions: day.sessions
                )

                AnalyticsSection(title: "Where your time went", detail: "apps and websites") {
                    if activities.isEmpty {
                        Text("Finish a focus session and Qasim will show the apps and sites that shaped your day.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        AnalyticsActivityBreakdown(activities: activities)
                    }
                }

                sessionSection(title: "Sessions", records: sessions)
            }
            .padding(24)
        }
    }

    private func todayOverview(_ day: DayFocus) -> some View {
        let goalMinutes = model.prefs.dailyGoalMinutes
        let progress = goalMinutes > 0 ? min(1, Double(day.focusMinutes) / Double(goalMinutes)) : 0
        let goalLabel = goalMinutes > 0
            ? "\(day.focusMinutes) / \(goalMinutes) min goal"
            : "No daily goal set"

        return AnalyticsSection {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("TODAY'S FOCUS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Palette.inkSoft)
                    Text(AnalyticsSummaryStrip.duration(day.focusedSeconds))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(todayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Text(day.totalSeconds > 0 ? "\(Int(day.focusPercent.rounded()))% focused" : "Ready when you are")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(day.totalSeconds > 0 ? Palette.good : Palette.inkSoft)
                    if goalMinutes > 0 {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(Palette.ember)
                            .frame(width: 190)
                        Text(goalLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.inkSoft)
                    } else {
                        Text(goalLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
    }

    private var historyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AnalyticsSection(title: monthTitle, detail: "Select a day") {
                    HStack(spacing: 10) {
                        Spacer()
                        Button("Today") {
                            month = Date()
                            selectedDay = Date()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                        Button {
                            month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        Button {
                            month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                    calendarGrid
                }

                selectedDaySection
            }
            .padding(24)
        }
    }

    private var calendarGrid: some View {
        let cells = model.progress.monthGrid(containing: month)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
            }
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                dayCell(cell)
            }
        }
    }

    private func dayCell(_ cell: DayFocus?) -> some View {
        guard let cell, let date = ProgressStore.date(from: cell.day) else {
            return AnyView(Color.clear.frame(height: 46))
        }
        let selected = ProgressStore.stamp(selectedDay) == cell.day
        let hasData = cell.totalSeconds > 0
        let dayNumber = Calendar.current.component(.day, from: date)
        let intensity = hasData ? min(0.85, 0.18 + cell.focusedSeconds / 9_000) : 0

        return AnyView(
            Button {
                selectedDay = date
            } label: {
                VStack(spacing: 3) {
                    Text("\(dayNumber)")
                        .font(.system(size: 12, weight: selected ? .bold : .medium))
                        .foregroundStyle(Palette.ink)
                    Text(hasData ? AnalyticsSummaryStrip.duration(cell.focusedSeconds) : " ")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hasData ? Palette.good.opacity(intensity) : Palette.paperDeep.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? Palette.ink : Palette.ink.opacity(0.07), lineWidth: selected ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
        )
    }

    private var selectedDaySection: some View {
        let day = model.progress.focus(on: selectedDay)
        let records = model.progress.sessions(on: selectedDay)
        let activities = model.progress.activityTotals(on: selectedDay)

        return AnalyticsSection(
            title: selectedDayTitle,
            detail: records.isEmpty ? "No completed sessions" : "\(records.count) session\(records.count == 1 ? "" : "s")"
        ) {
            AnalyticsSummaryStrip(
                productive: day.focusedSeconds,
                distracted: day.distractedSeconds,
                sessions: day.sessions
            )

            if records.isEmpty {
                Text("No sessions on this day.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                Divider().opacity(0.3)
                ForEach(records) { record in
                    sessionRow(record)
                }
            }

            if !activities.isEmpty {
                Divider().opacity(0.3)
                AnalyticsActivityBreakdown(activities: activities, limit: 4)
            }
        }
    }

    private func sessionSection(title: String, records: [SessionRecord]) -> some View {
        AnalyticsSection(title: title, detail: records.isEmpty ? nil : "\(records.count) logged") {
            if records.isEmpty {
                Text("No sessions yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(records) { record in
                    sessionRow(record)
                }
            }
        }
    }

    private func sessionRow(_ record: SessionRecord) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskTitle.isEmpty ? "Untitled session" : record.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(detailLine(for: record))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Text(scoreLabel(record.focusPercent, hasData: record.totalSeconds > 0))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(record.focusPercent >= 50 ? Palette.good : Palette.ember)
            Button("Restart") { model.restartSession(record) }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 3)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var todayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var selectedDayTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDay)
    }

    private func detailLine(for record: SessionRecord) -> String {
        let length = record.durationMinutes <= 0 ? "Stopwatch" : "\(record.durationMinutes)m"
        let time = Self.relative.localizedString(for: record.date, relativeTo: Date())
        let marker = record.finished ? "✓" : "•"
        return "\(marker) \(length) · \(record.strategy.title) · \(time)"
    }

    private func scoreLabel(_ percent: Double, hasData: Bool) -> String {
        hasData ? "\(Int(percent.rounded()))%" : "—"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
