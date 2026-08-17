import AppKit
import SwiftUI

/// The home dashboard shown after onboarding. Mirrors the Kiki pattern the user
/// wants: today's focus progress, a recent sessions list, and a single big
/// "NEW" button. The detailed new-session config (task/mode/apps/duration) is
/// reached by tapping NEW and opens in a separate panel.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = model.prefs

        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    todaySection
                    recentSessionsSection
                }
                .padding(22)
            }
            newSessionBar
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.prefs.companion.displayName)
                    .font(Typeface.display(28))
                    .foregroundStyle(Palette.ink)
                Text("One thing. Or the lights go out.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button("Progress") {
                model.openProgress()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .accessibilityLabel("Progress")
            Button("Customize") {
                model.openSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .accessibilityLabel("Customize")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var todaySection: some View {
        let today = model.progress.focus(on: Date())
        let todayMinutes = today.focusMinutes
        let goalMinutes = model.prefs.dailyGoalMinutes
        let progress = goalMinutes > 0 ? min(1, Double(todayMinutes) / Double(goalMinutes)) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(Typeface.display(20))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(goalMinutes > 0
                    ? "\(todayMinutes) / \(goalMinutes) min"
                    : "\(todayMinutes) min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Palette.ember)
                .frame(height: 8)
            Text("Focus Goal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(14)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
        )
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent sessions")
                    .font(Typeface.display(20))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(model.progress.recentSessions.count)/20")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            if model.progress.recentSessions.isEmpty {
                Text("No sessions yet. Tap NEW to start one.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(model.progress.recentSessions) { record in
                        sessionRow(record)
                    }
                }
            }
        }
    }

    private func sessionRow(_ record: SessionRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.taskTitle.isEmpty ? "Untitled session" : record.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(detailLine(for: record))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button {
                model.restartSession(record)
            } label: {
                Text("Restart")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Palette.ink)
                    )
            }
            .buttonStyle(.plain)
            .help("Start a new session with the same task and settings")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.cream)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func detailLine(for record: SessionRecord) -> String {
        let length = record.durationMinutes <= 0
            ? "Stopwatch"
            : "\(record.durationMinutes)m"
        let time = Self.relative.localizedString(for: record.date, relativeTo: Date())
        let dot = record.finished ? "\u{2713}" : "\u{2022}"
        return "\(dot) \(length) \u{00B7} \(record.strategy.title) \u{00B7} \(time)"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var newSessionBar: some View {
        VStack(spacing: 8) {
            Button {
                model.openNewSessionConfig()
            } label: {
                Text("NEW")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
        .background(Palette.paperDeep.opacity(0.5))
    }
}
