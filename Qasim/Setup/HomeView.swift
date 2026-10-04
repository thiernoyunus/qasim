import AppKit
import SwiftUI

/// The home screen shown after onboarding: the companion, today's progress
/// toward the daily goal, today's sessions, and one big New session bar.
/// When the window is made wide it splits into two columns.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    private var sessionActive: Bool {
        model.session.phase == .running || model.session.phase == .paused
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScreenHeader {
                    IconButton(systemName: "slider.horizontal.3", label: "Settings") { model.openSettings() }
                }
                .overlay(alignment: .leading) {
                    IconButton(systemName: "chart.bar", label: "Analytics") { model.openProgress() }
                        .padding(.leading, 12)
                }

                if geo.size.width >= 720 {
                    wideLayout
                } else {
                    narrowLayout
                }
            }
        }
        .background(Palette.ground)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }

    private var narrowLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CompanionVisibilityNotice()
                    greeting
                    todayCard
                    sessionsList
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            newSessionButton
                .buttonStyle(BarButtonStyle())
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(spacing: 22) {
                CompanionVisibilityNotice()
                greeting
                todayCard
                newSessionButton
                    .buttonStyle(BarButtonStyle())
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(width: 360)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    sessionsList
                    weekBars
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 32)
        .frame(maxWidth: 1100)
        .frame(maxWidth: .infinity)
    }

    private var greeting: some View {
        let name = model.prefs.userName.trimmingCharacters(in: .whitespaces)
        return VStack(spacing: 6) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(height: 140)
                .padding(.bottom, 8)
                .accessibilityLabel("\(model.prefs.companion.displayName), your companion")
            Text(name.isEmpty ? "Salaam." : "Salaam, \(name).")
                .font(.system(size: 24, weight: .bold))
            Text("One thing at a time.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var todayCard: some View {
        let minutes = model.progress.focus(on: Date()).focusMinutes
        let goal = model.prefs.dailyGoalMinutes
        let progress = goal > 0 ? min(1, Double(minutes) / Double(goal)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(minutes)").font(.system(size: 15, weight: .bold)).monospacedDigit()
                    + Text(goal > 0 ? " of \(goal) min" : " min").font(.system(size: 15)).foregroundColor(Palette.muted)
            }
            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.12))
                    Capsule().fill(Palette.ink).frame(width: bar.size.width * progress)
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel("Daily focus goal")
            .accessibilityValue("\(minutes) of \(goal) minutes")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.ink, lineWidth: 1.5))
    }

    private var sessionsList: some View {
        let sessions = model.progress.sessions(on: Date())
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Earlier today")
            if sessions.isEmpty {
                Text("No sessions yet today.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.muted)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { record in
                        SessionRow(record: record, detail: detailLine(for: record))
                        RowLine()
                    }
                }
            }
        }
    }

    private func detailLine(for record: SessionRecord) -> String {
        let length = record.durationMinutes <= 0 ? "Stopwatch" : "\(record.durationMinutes) min"
        let time = Self.relative.localizedString(for: record.date, relativeTo: Date())
        return "\(length) \u{00B7} \(record.strategy.title) \u{00B7} \(time)"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// Last seven days of focus, shown only in the wide layout.
    private var weekBars: some View {
        let calendar = Calendar.current
        let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: Date()) }
        let minutes = days.map { model.progress.focus(on: $0).focusMinutes }
        let peak = max(minutes.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("This week")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(zip(days, minutes)), id: \.0) { day, value in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(calendar.isDateInToday(day) ? Palette.ink.opacity(0.3) : Palette.ink)
                            .frame(maxWidth: 34)
                            .frame(height: max(4, 84 * CGFloat(value) / CGFloat(peak)))
                        Text(calendar.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 12, weight: calendar.isDateInToday(day) ? .bold : .regular))
                            .foregroundStyle(calendar.isDateInToday(day) ? Palette.ink : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue("\(value) minutes focused")
                }
            }
            .frame(height: 110, alignment: .bottom)
        }
    }

    private var newSessionButton: some View {
        Button(sessionActive ? "Edit current session" : "New session") {
            if sessionActive {
                model.openSessionEditor()
            } else {
                model.openNewSessionConfig()
            }
        }
        .keyboardShortcut(.defaultAction)
    }
}

/// A past session with a circular "run again" button, hidden while a session runs.
struct SessionRow: View {
    @Environment(AppModel.self) private var model
    let record: SessionRecord
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.taskTitle.isEmpty ? "Untitled session" : record.taskTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            if model.session.phase != .running && model.session.phase != .paused {
                Button {
                    model.restartSession(record)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Run \(record.taskTitle) again")
                .help("Start again with the same task and settings")
            }
        }
        .frame(minHeight: 56)
    }
}
