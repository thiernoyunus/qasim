import AppKit
import SwiftUI

enum AnalyticsTab: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}

/// Analytics: Today / Week / Month. Narrow windows stack everything in one
/// column; at 720pt and wider the chart sits left and the list sits right.
struct ProgressBoardView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AnalyticsTab
    /// Any day inside the week being shown.
    @State private var weekDay = Date()
    /// The selected day in the month calendar; its month is the month shown.
    @State private var monthDay = Date()

    private let calendar = Calendar.current

    init(initialTab: AnalyticsTab = .today) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader(title: "Analytics", back: { model.closeProgress() })
                if geo.size.width >= 720 {
                    HStack(alignment: .top, spacing: 56) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                tabPicker.frame(maxWidth: 360)
                                summary(wide: true)
                            }
                            .padding(.bottom, 32)
                        }
                        ScrollView {
                            detail.padding(.top, 6).padding(.bottom, 32)
                        }
                        .frame(width: (geo.size.width - 96 - 56) / 2.4)
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            tabPicker
                            summary(wide: false)
                            detail
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(Palette.ground)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }

    // MARK: - Shared pieces

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsTab.allCases, id: \.self) { option in
                let selected = tab == option
                Button { tab = option } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Palette.field)
                                    .shadow(color: Palette.ink.opacity(0.15), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func summary(wide: Bool) -> some View {
        switch tab {
        case .today: todaySummary
        case .week: weekSummary(wide: wide)
        case .month: monthSummary
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch tab {
        case .today: timeList(model.progress.activityTotals(on: Date()))
        case .week: timeList(model.progress.activityTotals(in: week))
        case .month: selectedDaySessions
        }
    }

    private func bigNumber(_ seconds: TimeInterval) -> some View {
        Text(Self.duration(seconds))
            .font(.system(size: 44, weight: .bold))
            .monospacedDigit()
    }

    private func muted(_ text: String) -> some View {
        Text(text).font(.system(size: 15)).foregroundStyle(Palette.muted)
    }

    private func swatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    /// ‹ title › row for stepping through weeks or months. Can't step into the future.
    private func stepper(_ title: String, unit: String, canGoForward: Bool, step: @escaping (Int) -> Void) -> some View {
        HStack {
            IconButton(systemName: "chevron.left", label: "Previous \(unit)") { step(-1) }
            Spacer()
            Text(title).font(.system(size: 15, weight: .semibold))
            Spacer()
            IconButton(systemName: "chevron.right", label: "Next \(unit)") { step(1) }
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.3)
        }
        .padding(.horizontal, -12)
    }

    private func timeList(_ activities: [ActivityStat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Where your time went")
            if activities.isEmpty {
                muted("Nothing tracked yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(activities.prefix(8)) { activity in
                        HStack(spacing: 12) {
                            AnalyticsActivityLogo(activity: activity)
                            Text(activity.name)
                                .font(.system(size: 15))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            if activity.distractedSeconds > activity.focusedSeconds {
                                Text("distraction")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.emberText)
                            }
                            Text(Self.duration(activity.totalSeconds))
                                .font(.system(size: 15))
                                .monospacedDigit()
                        }
                        .frame(minHeight: 48)
                        .accessibilityElement(children: .combine)
                        RowLine()
                    }
                }
            }
        }
    }

    // MARK: - Today

    private var todaySummary: some View {
        let day = model.progress.focus(on: Date())
        let count = model.progress.sessions(on: Date()).count
        let focused = Int(day.focusPercent.rounded())
        return VStack(alignment: .leading, spacing: 4) {
            bigNumber(day.focusedSeconds)
            if day.totalSeconds == 0 {
                muted("No focus yet today.")
            } else {
                muted("focused across \(count) session\(count == 1 ? "" : "s")")
                GeometryReader { bar in
                    HStack(spacing: 0) {
                        Palette.ink.frame(width: bar.size.width * day.focusedSeconds / day.totalSeconds)
                        Palette.distracted
                    }
                }
                .frame(height: 14)
                .clipShape(Capsule())
                .padding(.top, 12)
                .accessibilityElement()
                .accessibilityLabel("\(focused) percent focused, \(100 - focused) percent distracted")
                HStack(spacing: 18) {
                    swatch(Palette.ink, "Focused \(focused)%")
                    swatch(Palette.distracted, "Distracted \(100 - focused)%")
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .padding(.top, 4)
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Week

    private var week: DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: weekDay) ?? DateInterval(start: weekDay, duration: 7 * 86_400)
    }

    private func weekSummary(wide: Bool) -> some View {
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
        let focus = days.map { model.progress.focus(on: $0) }
        let total = focus.reduce(0) { $0 + $1.focusedSeconds }
        let goal = model.prefs.dailyGoalMinutes
        let met = focus.filter { goal > 0 && $0.focusMinutes >= goal }.count
        let isThisWeek = week.contains(Date())
        let range = "\(week.start.formatted(.dateTime.month(.abbreviated).day())) – "
            + (days.last ?? week.start).formatted(.dateTime.month(.abbreviated).day())
        let best = zip(days, focus).max { $0.1.focusedSeconds < $1.1.focusedSeconds }

        return VStack(alignment: .leading, spacing: 4) {
            stepper(range, unit: "week", canGoForward: !isThisWeek) { step in
                weekDay = min(Date(), calendar.date(byAdding: .day, value: 7 * step, to: weekDay) ?? weekDay)
            }
            bigNumber(total)
            if total == 0 {
                muted(isThisWeek ? "No focus yet this week." : "No focus this week.")
            } else {
                muted(goal > 0 ? "focused \u{00B7} goal met \(met) of 7 days" : "focused")
                weekChart(days: days, focus: focus, height: wide ? 210 : 130, barWidth: wide ? 44 : 28)
                    .padding(.top, 18)
                HStack(spacing: 18) {
                    swatch(Palette.ink, "Focused")
                    swatch(Palette.distracted, "Distracted")
                    Spacer()
                    if let best {
                        Text("Best day: \(best.0.formatted(.dateTime.weekday(.wide)))")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .padding(.top, 8)
            }
        }
    }

    private func weekChart(days: [Date], focus: [DayFocus], height: CGFloat, barWidth: CGFloat) -> some View {
        let goal = Double(model.prefs.dailyGoalMinutes)
        let scale = max(focus.map { $0.totalSeconds / 60 }.max() ?? 0, goal * 1.2, 1)
        func barHeight(_ seconds: TimeInterval) -> CGFloat { height * CGFloat(seconds / 60 / scale) }

        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(zip(days, focus)), id: \.0) { day, value in
                    VStack(spacing: 0) {
                        Palette.distracted.frame(height: barHeight(value.distractedSeconds))
                        Palette.ink.frame(height: barHeight(value.focusedSeconds))
                    }
                    .frame(width: barWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(
                        "\(Self.duration(value.focusedSeconds)) focused, \(Self.duration(value.distractedSeconds)) distracted"
                    )
                }
            }
            .frame(height: height, alignment: .bottom)
            .overlay(alignment: .bottom) {
                if goal > 0 {
                    HLine()
                        .stroke(Palette.muted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(height: 1.5)
                        .overlay(alignment: .bottomTrailing) {
                            Text("goal \(Self.goalText(Int(goal)))")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                                .padding(.bottom, 4)
                        }
                        .offset(y: -barHeight(goal * 60))
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let today = calendar.isDateInToday(day)
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 13, weight: today ? .bold : .regular))
                        .foregroundStyle(today ? Palette.ink : Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Month

    private var monthSummary: some View {
        let interval = calendar.dateInterval(of: .month, for: monthDay) ?? DateInterval(start: monthDay, duration: 0)
        let count = calendar.range(of: .day, in: .month, for: monthDay)?.count ?? 30
        let dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        let focus = dates.map { model.progress.focus(on: $0) }
        let total = focus.reduce(0) { $0 + $1.focusedSeconds }
        let focusedDays = focus.filter { $0.focusedSeconds > 0 }.count
        let lead = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let symbols = calendar.veryShortWeekdaySymbols
        let headers = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])

        return VStack(alignment: .leading, spacing: 4) {
            stepper(monthDay.formatted(.dateTime.month(.wide).year()), unit: "month",
                    canGoForward: !interval.contains(Date())) { step in
                monthDay = min(Date(), calendar.date(byAdding: .month, value: step, to: monthDay) ?? monthDay)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                bigNumber(total)
                muted(focusedDays == 0 ? "No focus this month." : "focused on \(focusedDays) day\(focusedDays == 1 ? "" : "s")")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 44) }
                ForEach(Array(zip(dates, focus)), id: \.0) { date, value in
                    dayCell(date, value)
                }
            }
            .padding(.top, 16)
            HStack(spacing: 6) {
                Text("Less")
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 4).fill(Self.shade(level)).frame(width: 14, height: 14)
                }
                Text("More focus")
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.muted)
            .padding(.top, 10)
            .accessibilityHidden(true)
        }
    }

    private func dayCell(_ date: Date, _ value: DayFocus) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: monthDay)
        let level = Self.level(minutes: value.focusMinutes, goal: model.prefs.dailyGoalMinutes)
        return Button { monthDay = date } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: calendar.isDateInToday(date) ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(level >= 3 ? Palette.field : Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Self.shade(level), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Palette.ink, lineWidth: 2)
                            .padding(-3.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(value.focusedSeconds > 0 ? "\(Self.duration(value.focusedSeconds)) focused" : "No focus")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedDaySessions: some View {
        let records = model.progress.sessions(on: monthDay)
        let focused = model.progress.focus(on: monthDay).focusedSeconds
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(monthDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                + " \u{00B7} \(Self.duration(focused))")
            if records.isEmpty {
                muted("No sessions on this day.")
            } else {
                VStack(spacing: 0) {
                    ForEach(records) { record in
                        let length = record.durationMinutes <= 0 ? "Stopwatch" : "\(record.durationMinutes) min"
                        SessionRow(
                            record: record,
                            detail: "\(length) \u{00B7} \(record.strategy.title) \u{00B7} "
                                + record.date.formatted(date: .omitted, time: .shortened)
                        )
                        RowLine()
                    }
                }
            }
        }
    }

    // MARK: - Formatting

    /// "58m", "1h 05m".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)m" : String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }

    /// "2h" for whole hours, otherwise like `duration`.
    private static func goalText(_ minutes: Int) -> String {
        minutes >= 60 && minutes % 60 == 0 ? "\(minutes / 60)h" : duration(TimeInterval(minutes * 60))
    }

    /// 0 = nothing, 1–4 = share of the daily goal (2h when no goal is set).
    private static func level(minutes: Int, goal: Int) -> Int {
        guard minutes > 0 else { return 0 }
        let share = Double(minutes) / Double(goal > 0 ? goal : 120)
        return share < 0.25 ? 1 : share < 0.6 ? 2 : share < 1 ? 3 : 4
    }

    private static func shade(_ level: Int) -> Color {
        switch level {
        case 1: Color(red: 0.890, green: 0.855, blue: 0.796)
        case 2: Color(red: 0.725, green: 0.678, blue: 0.608)
        case 3: Color(red: 0.431, green: 0.388, blue: 0.349)
        case 4: Palette.ink
        default: Palette.ink.opacity(0.05)
        }
    }
}

private struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// App icon or website favicon for an activity row.
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

    /// The site's own favicon, fetched from the site itself. The user has
    /// already visited it, so no third-party icon service learns their history.
    private var websiteLogoURL: URL? {
        guard activity.kind == .website, let host = websiteHost else { return nil }
        return URL(string: "https://\(host)/favicon.ico")
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
            } else if let websiteLogoURL {
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
            } else {
                fallbackLogo
            }
        }
        .frame(width: 24, height: 24)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Shown while a favicon loads, or when a site has none.
    private var fallbackLogo: some View {
        Text(String(activity.name.first ?? "?").uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
