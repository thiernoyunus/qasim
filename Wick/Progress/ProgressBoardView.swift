import SwiftUI

struct ProgressBoardView: View {
    @Environment(AppModel.self) private var model
    @State private var month = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(model.prefs.companion.assetName(for: .typing))
                        .resizable()
                        .scaledToFit()
                        .frame(height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The days you showed up.")
                            .font(Typeface.display(24))
                            .foregroundStyle(Palette.ink)
                        let today = model.progress.focus(on: Date())
                        Text("Today: \(format(today.focusedSeconds)) focused")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                }

                HStack {
                    Button {
                        month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(monthTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button {
                        month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Palette.ink)

                let cells = model.progress.monthGrid(containing: month)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, d in
                        Text(d)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        dayCell(cell)
                    }
                }

                Text("Green means you actually sat down and did the thing. Empty means you didn’t. Wick doesn’t sugarcoat it.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)

                recentSessionsSection

                Spacer(minLength: 8)
            }
            .padding(22)
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent sessions")
                    .font(Typeface.display(20))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(model.progress.recentSessions.count)/20")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
            }
            if model.progress.recentSessions.isEmpty {
                Text("No sessions yet. Start one and it’ll land here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                VStack(spacing: 6) {
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
        let dot = record.finished ? "✓" : "•"
        return "\(dot) \(length) · \(record.strategy.title) · \(time)"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    @ViewBuilder
    private func dayCell(_ cell: DayFocus?) -> some View {
        if let cell {
            let minutes = cell.focusMinutes
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(minutes == 0 ? Palette.cream : Palette.good.opacity(min(1, 0.25 + Double(minutes) / 90)))
                .overlay {
                    Text(minutes == 0 ? "·" : "\(minutes)m")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Palette.ink.opacity(0.08), lineWidth: 1)
                )
                .frame(height: 34)
        } else {
            Color.clear.frame(height: 34)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }
}
