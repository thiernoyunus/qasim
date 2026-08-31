import Charts
import SwiftUI

enum StatsRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case fourteen = 14
    case thirty = 30

    var id: Int { rawValue }
    var title: String { "\(rawValue) days" }
}

/// One day of the range, pre-flattened for Charts. Using a plain index keeps the
/// bars evenly spaced and wide instead of squeezed onto a continuous date scale.
private struct StatsDay: Identifiable {
    let id: Int
    let date: Date
    let productiveMinutes: Double
    let distractedMinutes: Double
    let score: Double
    var hasData: Bool { productiveMinutes + distractedMinutes > 0 }
}

/// Hover readout shared by both charts.
private struct ChartTooltip: View {
    let day: StatsDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)

            row(color: Palette.good, text: "\(minutes(day.productiveMinutes)) productive")
            row(color: Palette.ember, text: "\(minutes(day.distractedMinutes)) distracting")

            Divider().opacity(0.25)

            HStack(spacing: 6) {
                Text("Focus")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSoft)
                Text(day.hasData ? "\(Int(day.score.rounded()))%" : "—")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.wax)
            }
        }
        .padding(10)
        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Palette.ink.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Palette.ink.opacity(0.16), radius: 8, y: 3)
        .fixedSize()
    }

    private func row(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Palette.ink)
        }
    }

    private func minutes(_ value: Double) -> String {
        let total = Int(value.rounded())
        if total < 60 { return "\(total)m" }
        let rest = total % 60
        return rest == 0 ? "\(total / 60)h" : "\(total / 60)h \(rest)m"
    }
}

private struct StatsRangePicker: View {
    @Binding var selection: StatsRange

    var body: some View {
        HStack(spacing: 3) {
            ForEach(StatsRange.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selection == option ? Palette.cream : Palette.inkSoft)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selection == option ? Palette.ink : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Palette.paper.opacity(0.48), in: Capsule())
        .overlay(Capsule().stroke(Palette.ink.opacity(0.07), lineWidth: 1))
    }
}

struct StatsBoardView: View {
    @Environment(AppModel.self) private var model
    @State private var range: StatsRange = .seven
    @State private var hoveredTimeID: Int?

    private var startDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -(range.rawValue - 1),
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date()
    }

    private var days: [DayFocus] {
        model.progress.daySeries(last: range.rawValue)
    }

    private var series: [StatsDay] {
        days.enumerated().map { index, day in
            StatsDay(
                id: index,
                date: ProgressStore.date(from: day.day) ?? Date(),
                productiveMinutes: day.focusedSeconds / 60,
                distractedMinutes: day.distractedSeconds / 60,
                score: day.focusPercent
            )
        }
    }

    private var sessions: [SessionRecord] {
        model.progress.sessions(since: startDate)
    }

    private var activities: [ActivityStat] {
        model.progress.activityTotals(since: startDate)
    }

    private var productiveSeconds: TimeInterval {
        days.reduce(0) { $0 + $1.focusedSeconds }
    }

    private var distractedSeconds: TimeInterval {
        days.reduce(0) { $0 + $1.distractedSeconds }
    }

    private var trackedSeconds: TimeInterval {
        productiveSeconds + distractedSeconds
    }

    private var overallScore: Double {
        guard trackedSeconds > 0 else { return 0 }
        return productiveSeconds / trackedSeconds * 100
    }

    /// Show every label at 7d, then thin them out so they never collide.
    private var axisIndices: [Int] {
        let step = range == .seven ? 1 : (range == .fourteen ? 2 : 5)
        return series.map(\.id).filter { $0.isMultiple(of: step) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overallSummary
                productiveChart
                if !activities.isEmpty {
                    AnalyticsSection(title: "Where your time went", detail: "top apps and websites") {
                        AnalyticsActivityBreakdown(activities: activities)
                    }
                }
            }
            .padding(24)
        }
    }

    private var overallSummary: some View {
        AnalyticsSection {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Focus report")
                        .font(Typeface.display(19, weight: .semibold))
                    Text("A \(range.rawValue)-day view of your rhythm.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                StatsRangePicker(selection: $range)
            }

            AnalyticsSummaryStrip(
                productive: productiveSeconds,
                distracted: distractedSeconds,
                sessions: sessions.count
            )
        }
    }

    private var productiveChart: some View {
        AnalyticsSection(
            title: "Daily focus",
            detail: "\(AnalyticsSummaryStrip.duration(productiveSeconds)) productive · \(range.rawValue) days"
        ) {
            if trackedSeconds == 0 {
                emptyChart("Complete a session to see your daily split.")
            } else {
                HStack(spacing: 14) {
                    legend(color: Palette.good, text: "productive")
                    legend(color: Palette.ember, text: "distracting")
                }
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkSoft)

                Chart(series) { day in
                    BarMark(
                        x: .value("Day", day.id),
                        y: .value("Minutes", day.productiveMinutes),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(Palette.good.opacity(hoveredTimeID == nil || hoveredTimeID == day.id ? 0.9 : 0.35))
                    .cornerRadius(3)
                    BarMark(
                        x: .value("Day", day.id),
                        y: .value("Minutes", day.distractedMinutes),
                        width: .fixed(barWidth)
                    )
                    .foregroundStyle(Palette.ember.opacity(hoveredTimeID == nil || hoveredTimeID == day.id ? 0.75 : 0.3))
                    .cornerRadius(3)
                }
                .chartXAxis { indexAxis }
                .chartXScale(domain: -0.7...(Double(series.count) - 0.3))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(minuteLabel(minutes))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.inkSoft)
                            }
                        }
                    }
                }
                .frame(height: 190)
                .chartOverlay { proxy in hoverOverlay(proxy, selection: $hoveredTimeID) }
            }
        }
    }

    private var barWidth: CGFloat {
        switch range {
        case .seven: 26
        case .fourteen: 16
        case .thirty: 8
        }
    }

    private let tooltipWidth: CGFloat = 150
    private let tooltipHeight: CGFloat = 100
    private let tooltipGap: CGFloat = 4

    /// Tracks the pointer across the plot and shows the nearest day's readout.
    private func hoverOverlay(
        _ proxy: ChartProxy,
        selection: Binding<Int?>
    ) -> some View {
        GeometryReader { geo in
            let plot = proxy.plotFrame.map { geo[$0] } ?? .zero
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.clear).contentShape(Rectangle())

                if let day = hoveredDay(id: selection.wrappedValue),
                   let x = proxy.position(forX: day.id) {
                    let lineX = plot.minX + x
                    let yValue = day.productiveMinutes + day.distractedMinutes
                    let pointY = plot.minY + (proxy.position(forY: yValue) ?? 0)

                    Rectangle()
                        .fill(Palette.ink.opacity(0.18))
                        .frame(width: 1, height: plot.height)
                        .position(x: lineX, y: plot.midY)

                    ChartTooltip(day: day)
                        .position(
                            x: tooltipCenterX(center: lineX, width: geo.size.width),
                            y: tooltipCenterY(point: pointY, plot: plot)
                        )
                        .allowsHitTesting(false)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    guard plot.contains(point) else { selection.wrappedValue = nil; return }
                    let local = point.x - plot.minX
                    guard let raw: Double = proxy.value(atX: local) else { return }
                    selection.wrappedValue = series.min {
                        abs(Double($0.id) - raw) < abs(Double($1.id) - raw)
                    }?.id
                case .ended:
                    selection.wrappedValue = nil
                }
            }
        }
    }

    private func hoveredDay(id: Int?) -> StatsDay? {
        guard let id else { return nil }
        return series.first { $0.id == id }
    }

    /// Keeps the card centered on the guide without letting it hang off an edge.
    private func tooltipCenterX(center: CGFloat, width: CGFloat) -> CGFloat {
        let minimum = tooltipWidth / 2
        let maximum = max(minimum, width - minimum)
        return min(max(center, minimum), maximum)
    }

    /// Places the card above the mark when possible, otherwise below it.
    private func tooltipCenterY(point: CGFloat, plot: CGRect) -> CGFloat {
        let preferredTop = point - tooltipHeight - tooltipGap
        let top = preferredTop >= plot.minY
            ? preferredTop
            : point + tooltipGap
        let minimum = plot.minY + tooltipGap
        let maximum = max(minimum, plot.maxY - tooltipHeight - tooltipGap)
        return min(max(top, minimum), maximum) + tooltipHeight / 2
    }

    private var indexAxis: some AxisContent {
        AxisMarks(values: axisIndices) { value in
            AxisGridLine().foregroundStyle(Palette.ink.opacity(0.06))
            AxisValueLabel {
                if let index = value.as(Int.self), let day = series.first(where: { $0.id == index }) {
                    Text(day.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }

    private func minuteLabel(_ minutes: Double) -> String {
        let value = Int(minutes.rounded())
        if value < 60 { return "\(value)m" }
        let hours = value / 60
        let rest = value % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    private func emptyChart(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60, alignment: .center)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}
